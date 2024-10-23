<?php

require 'User.php';

class UserController {
    // Retorna todos os usuários
    public function index() {
        return User::all();
    }

    // Cria um novo usuário
    public function create($data) {
        if (User::emailExists($data['email'])) {
            throw new Exception("Email já cadastrado!");
        }

        return User::create([
            'name' => $data['name'],
            'email' => $data['email'],
            'password' => password_hash($data['password'], PASSWORD_DEFAULT)
        ]);
    }

    // Atualiza um usuário existente
    public function update($id, $data) {
        $user = User::find($id);
        if ($user) {
            $user->updateUser($data);
            return $user;
        }
        throw new Exception("Usuário não encontrado!");
    }

    // Deleta um usuário
    public function delete($id) {
        $user = User::find($id);
        if ($user) {
            $user->deleteUser();
            return true;
        }
        throw new Exception("Usuário não encontrado!");
    }
}
