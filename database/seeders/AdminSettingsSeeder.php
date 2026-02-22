<?php

namespace Database\Seeders;

use App\Models\AdminSetting;
use Illuminate\Database\Seeder;

class AdminSettingsSeeder extends Seeder
{
    public function run()
    {
        $defaultSettings = [
            [
                'key' => 'general.instanceName',
                'value' => 'My Loops Instance',
                'type' => 'string',
                'is_public' => true,
                'description' => 'The display name of this Loops instance',
            ],
            [
                'key' => 'general.instanceUrl',
                'value' => config('app.url'),
                'type' => 'string',
                'is_public' => true,
                'description' => 'The primary URL for this instance',
            ],
            [
                'key' => 'general.instanceDescription',
                'value' => 'A creative community for sharing short videos and connecting with others.',
                'type' => 'string',
                'is_public' => true,
                'description' => 'Description shown on the instance homepage',
            ],
            [
                'key' => 'general.adminEmail',
                'value' => 'admin@example.com',
                'type' => 'string',
                'is_public' => false,
                'description' => 'Primary administrator email address',
            ],
            [
                'key' => 'general.supportEmail',
                'value' => 'support@example.com',
                'type' => 'string',
                'is_public' => true,
                'description' => 'Support contact email address',
            ],
            [
                'key' => 'general.supportForum',
                'value' => 'https://github.com/joinloops/loops-server/discussions',
                'type' => 'string',
                'is_public' => true,
                'description' => 'Support forum',
            ],
            [
                'key' => 'general.supportFediverseAccount',
                'value' => null,
                'type' => 'string',
                'is_public' => true,
                'description' => 'Support forum',
            ],
            [
                'key' => 'general.openRegistration',
                'value' => false,
                'type' => 'boolean',
                'is_public' => true,
                'description' => 'Allow new users to register without approval',
            ],
            [
                'key' => 'general.emailVerification',
                'value' => true,
                'type' => 'boolean',
                'is_public' => true,
                'description' => 'Require email verification for new accounts',
            ],
            [
                'key' => 'general.defaultContentStatus',
                'value' => 'published',
                'type' => 'string',
                'is_public' => false,
                'description' => 'Default status for new content uploads',
            ],
            [
                'key' => 'general.autoModerateNSFW',
                'value' => true,
                'type' => 'boolean',
                'is_public' => false,
                'description' => 'Automatically flag potentially NSFW content for review',
            ],
            [
                'key' => 'branding.logo',
                'value' => null,
                'type' => 'string',
                'is_public' => true,
                'description' => 'Instance logo image URL',
            ],
            [
                'key' => 'branding.favicon',
                'value' => null,
                'type' => 'string',
                'is_public' => true,
                'description' => 'Instance favicon URL',
            ],
            [
                'key' => 'branding.primaryColor',
                'value' => '#3b82f6',
                'type' => 'string',
                'is_public' => true,
                'description' => 'Primary brand color',
            ],
            [
                'key' => 'branding.secondaryColor',
                'value' => '#8b5cf6',
                'type' => 'string',
                'is_public' => true,
                'description' => 'Secondary brand color',
            ],
            [
                'key' => 'branding.accentColor',
                'value' => '#10b981',
                'type' => 'string',
                'is_public' => true,
                'description' => 'Accent brand color',
            ],
            [
                'key' => 'branding.customCSS',
                'value' => '',
                'type' => 'string',
                'is_public' => true,
                'description' => 'Custom CSS to be applied to the frontend',
            ],

            // Media Settings
            [
                'key' => 'media.maxVideoSize',
                'value' => 500,
                'type' => 'number',
                'is_public' => true,
                'description' => 'Maximum video file size in MB',
            ],
            [
                'key' => 'media.maxImageSize',
                'value' => 10,
                'type' => 'number',
                'is_public' => true,
                'description' => 'Maximum image file size in MB',
            ],
            [
                'key' => 'media.maxVideoDuration',
                'value' => 180,
                'type' => 'number',
                'is_public' => true,
                'description' => 'Maximum video duration in seconds',
            ],
            [
                'key' => 'media.allowedVideoFormats',
                'value' => ['mp4'],
                'type' => 'array',
                'is_public' => true,
                'description' => 'Allowed video file formats',
            ],
            [
                'key' => 'media.storageDriver',
                'value' => 'local',
                'type' => 'string',
                'is_public' => false,
                'description' => 'Storage driver for media files',
            ],
            [
                'key' => 'media.bucketName',
                'value' => '',
                'type' => 'string',
                'is_public' => false,
                'description' => 'Cloud storage bucket name',
            ],
            [
                'key' => 'media.cdnUrl',
                'value' => '',
                'type' => 'string',
                'is_public' => false,
                'description' => 'CDN URL for media files',
            ],
            [
                'key' => 'media.autoThumbnails',
                'value' => true,
                'type' => 'boolean',
                'is_public' => false,
                'description' => 'Automatically generate thumbnails for videos',
            ],
            [
                'key' => 'media.videoTranscoding',
                'value' => false,
                'type' => 'boolean',
                'is_public' => false,
                'description' => 'Enable video transcoding for optimization',
            ],
            [
                'key' => 'federation.enableFederation',
                'value' => false,
                'type' => 'boolean',
                'is_public' => true,
                'description' => 'Enable ActivityPub federation',
            ],
            [
                'key' => 'federation.federationMode',
                'value' => 'open',
                'type' => 'string',
                'is_public' => true,
                'description' => 'Federation mode: open, allowlist, or blocklist',
            ],
            [
                'key' => 'federation.allowedInstances',
                'value' => [],
                'type' => 'array',
                'is_public' => false,
                'description' => 'List of allowed federated instances',
            ],
            [
                'key' => 'federation.blockedInstances',
                'value' => [],
                'type' => 'array',
                'is_public' => false,
                'description' => 'List of blocked federated instances',
            ],
            [
                'key' => 'federation.autoAcceptFollows',
                'value' => true,
                'type' => 'boolean',
                'is_public' => false,
                'description' => 'Automatically accept follow requests from federated users',
            ],
            [
                'key' => 'federation.authorizedFetch',
                'value' => false,
                'type' => 'boolean',
                'is_public' => false,
                'description' => 'Enforce http signatures on actor/activity endpoints',
            ],
            [
                'key' => 'federation.rateLimit',
                'value' => 1000,
                'type' => 'number',
                'is_public' => false,
                'description' => 'Federation rate limit in requests per hour',
            ],
        ];

        foreach ($defaultSettings as $setting) {
            AdminSetting::updateOrCreate(
                ['key' => $setting['key']],
                [
                    'value' => $setting['value'],
                    'type' => $setting['type'],
                    'is_public' => $setting['is_public'],
                    'description' => $setting['description'],
                    'version' => 1,
                ]
            );
        }

        $this->command->info('Default admin settings have been seeded.');
    }
}
