<?php

use Illuminate\Database\Eloquent\Model;

class User extends Model {
    protected $table = 'users';
    public $timestamps = true; // Usar created_at e updated_at automaticamente
    protected $fillable = ['name', 'email', 'password']; // Campos que podem ser preenchidos em massa

    // Verifica se o email já existe no banco
    public static function emailExists($email) {
        return self::where('email', $email)->exists();
    }

    // Atualiza os dados do usuário
    public function updateUser($data) {
        $this->name = $data['name'];
        $this->email = $data['email'];
        $this->save();
    }
    
    // Deleta o usuário
    public function deleteUser() {
        return $this->delete();
    }
}
