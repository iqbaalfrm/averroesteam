<?php

namespace App\Models;

use Laravel\Sanctum\PersonalAccessToken as SanctumPersonalAccessToken;
use MongoDB\Laravel\Eloquent\DocumentModel;

/**
 * Override Sanctum PersonalAccessToken agar menyimpan ke MongoDB.
 * Menggunakan trait DocumentModel dari mongodb/laravel-mongodb.
 */
class PersonalAccessToken extends SanctumPersonalAccessToken
{
    use DocumentModel;

    protected $connection = 'mongodb';
    protected $collection = 'personal_access_tokens';
}
