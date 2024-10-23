<?php

use Illuminate\Database\Eloquent\Model;

class User extends Model {
    protected $table = 'users';
    public $timestamps = true; // Usar created_at e updated_at automaticamente
    protected $fillable = ['name', 'email', 'password']; // Campos que podem ser preenchidos em massa

    public static function createUser($data) {
        if (self::emailExists($data['email'])) {
            throw new Exception("Email já cadastrado!");
        }
        return self::create([
            'name' => $data['name'],
            'email' => $data['email'],
            'password' => password_hash($data['password'], PASSWORD_DEFAULT)
        ]);
    }

    public static function emailExists($email) {
        return self::where('email', $email)->exists();
    }

    public function updateUser($data) {
        $this->name = $data['name'];
        $this->email = $data['email'];
        $this->save();
    }
    
    public function deleteUser() {
        return $this->delete();
    }
}

