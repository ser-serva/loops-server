<?php

namespace Tests\Unit\Jobs;

use App\Jobs\Video\VideoOptimizeJob;
use App\Models\Video;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Storage;
use Mockery;
use ProtoneMedia\LaravelFFMpeg\Support\FFMpeg;
use Tests\TestCase;

/**
 * Unit tests for VideoOptimizeJob passthrough detection (FR-007).
 *
 * These tests verify that VideoOptimizeJob skips X264 re-encoding for videos
 * that are already encoded at ≤720p H.264, and encodes all other formats.
 *
 * Four cases per the spec:
 *   1. h264 + 720p   → passthrough (vid_optimized = vid, status = 2, no encode)
 *   2. h264 + 480p   → passthrough
 *   3. hevc + 720p   → encode (wrong codec)
 *   4. h264 + 1080p  → encode (height exceeds 720)
 */
class VideoOptimizeJobTest extends TestCase
{
    // ─── Helpers ─────────────────────────────────────────────────────────────

    /**
     * Build a Mockery mock that behaves like a Video Eloquent model.
     */
    private function makeVideoMock(
        string $vid = 'uploads/test.mp4',
        ?string $vidOptimized = null,
        int $status = 1,
    ): object {
        $video = Mockery::mock(Video::class)->makePartial();
        $video->vid = $vid;
        $video->vid_optimized = $vidOptimized;
        $video->has_processed = false;
        $video->has_audio = false;
        $video->status = $status;
        $video->id = 1;
        $video->shouldReceive('withoutRelations')->andReturnSelf();
        $video->shouldReceive('fresh')->andReturnSelf();
        $video->shouldReceive('save')->andReturn(true);

        return $video;
    }

    /**
     * Build a Mockery mock for a ProtoneMedia media-info object with the given
     * codec name and dimensions. Also wires the FFMpeg facade so that
     * `FFMpeg::fromDisk('s3')->open(anything)` returns $this media info.
     */
    private function setupFFMpegProbe(
        string $codecName,
        int $height,
        int $width = 1280,
    ): void {
        $videoStream = Mockery::mock();
        $videoStream->shouldReceive('get')->with('codec_name')->andReturn($codecName);
        $videoStream->shouldReceive('get')->with('height')->andReturn($height);
        $videoStream->shouldReceive('get')->with('width')->andReturn($width);

        $audioStream = Mockery::mock();

        $mediaInfo = Mockery::mock();
        $mediaInfo->shouldReceive('getVideoStream')->andReturn($videoStream);
        $mediaInfo->shouldReceive('getAudioStream')->andReturn($audioStream);
        // The encode path adds filters and exports — allow those but throw to
        // abort early so the test can inspect the pre-encode state.
        $mediaInfo->shouldReceive('addFilter')->andReturnSelf();
        $mediaInfo->shouldReceive('export')->andThrow(
            \RuntimeException::class,
            'mock: encode path reached',
        );

        $fromDiskBuilder = Mockery::mock();
        $fromDiskBuilder->shouldReceive('open')->andReturn($mediaInfo);
        FFMpeg::shouldReceive('fromDisk')->with('s3')->andReturn($fromDiskBuilder);
    }

    /**
     * Fake S3 with $vid present but the 720p-optimised variant absent.
     */
    private function fakeS3WithSourceOnly(string $vid = 'uploads/test.mp4'): void
    {
        Storage::fake('s3');
        Storage::disk('s3')->put($vid, 'dummy-video-bytes');
        // do NOT put the .720p.mp4 variant — must not exist beforehand
    }

    // ─── Passthrough cases ────────────────────────────────────────────────────

    /**
     * @test
     * FR-007 / US2-SC1: h264 at 720p → immediate passthrough, no encode.
     */
    public function passthrough_h264_at_720p_sets_vid_optimized_and_status_2(): void
    {
        $this->fakeS3WithSourceOnly();
        $video = $this->makeVideoMock();
        $this->setupFFMpegProbe('h264', 720);

        Log::shouldReceive('info')->once()->with(
            'VideoOptimizeJob: passthrough (already 720p H.264)',
            Mockery::any(),
        );

        // Job must NOT call FFMpeg encode chain → no call to export()
        // (verified implicitly: setupFFMpegProbe makes export() throw, so if
        //  it were called the test would fail with the RuntimeException)
        $job = new VideoOptimizeJob($video);
        $job->handle();

        $this->assertEquals($video->vid, $video->vid_optimized, 'vid_optimized must equal vid (passthrough)');
        $this->assertTrue((bool) $video->has_processed, 'has_processed must be true');
        $this->assertEquals(2, $video->status, 'status must be 2 (published-ready)');
    }

    /**
     * @test
     * FR-007: h264 at 480p (below 720) → also passthrough.
     */
    public function passthrough_h264_at_480p_sets_vid_optimized_and_status_2(): void
    {
        $this->fakeS3WithSourceOnly();
        $video = $this->makeVideoMock();
        $this->setupFFMpegProbe('h264', 480, 854);

        Log::shouldReceive('info')->once();

        $job = new VideoOptimizeJob($video);
        $job->handle();

        $this->assertEquals($video->vid, $video->vid_optimized);
        $this->assertTrue((bool) $video->has_processed);
        $this->assertEquals(2, $video->status);
    }

    // ─── Encode cases (passthrough must NOT trigger) ──────────────────────────

    /**
     * @test
     * FR-007 / US2-SC2: hevc at 720p → encode path, passthrough must not fire.
     */
    public function no_passthrough_hevc_at_720p_enters_encode_path(): void
    {
        $this->fakeS3WithSourceOnly();
        $video = $this->makeVideoMock();
        $this->setupFFMpegProbe('hevc', 720);

        // encode path is reached → our mock throws RuntimeException
        $this->expectException(\RuntimeException::class);
        $this->expectExceptionMessage('mock: encode path reached');

        $job = new VideoOptimizeJob($video);
        $job->handle();

        // If we reach here the passthrough triggered wrongly — fail
        $this->assertNull(
            $video->vid_optimized,
            'vid_optimized must not be set when encode path is taken',
        );
    }

    /**
     * @test
     * FR-007 / US2-SC2: h264 at 1080p → encode path, passthrough must not fire.
     */
    public function no_passthrough_h264_at_1080p_enters_encode_path(): void
    {
        $this->fakeS3WithSourceOnly();
        $video = $this->makeVideoMock();
        $this->setupFFMpegProbe('h264', 1080, 1920);

        // encode path is reached → our mock throws RuntimeException
        $this->expectException(\RuntimeException::class);
        $this->expectExceptionMessage('mock: encode path reached');

        $job = new VideoOptimizeJob($video);
        $job->handle();
    }
}
