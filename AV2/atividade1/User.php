<?php

use Illuminate\Database\Eloquent\Model;

class User extends Model {
    protected $table = 'users';
    public $timestamps = true; // Usar created_at e updated_at automaticamente
    protected $fillable = ['name', 'email', 'password']; // Campos que podem ser preenchidos em massa
}
