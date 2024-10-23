<?php 
require 'bootstrap.php';
require 'User.php';

// Lida com a criação de usuários
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action'])) {
    $action = $_POST['action'];

    switch ($action) {
        case 'create':
            createUser($_POST);
            break;

        case 'update':
            updateUser($_POST);
            break;

        case 'delete':
            deleteUser($_POST['delete_id']);
            break;
    }
}

// Lida com a exibição dos usuários
function displayUsers() {
    $users = User::all();
    echo "<h2>Usuários cadastrados</h2>";
    foreach ($users as $user) {
        echo htmlspecialchars($user->id) . " - " . htmlspecialchars($user->name) . " - " . htmlspecialchars($user->email) . "<br>";
    }
}

// Função para criar um usuário
function createUser($data) {
    if (isset($data['name'], $data['email'], $data['password'])) {
        $user = User::create([
            'name' => $data['name'],
            'email' => $data['email'],
            'password' => password_hash($data['password'], PASSWORD_DEFAULT)
        ]);
        echo "Usuário criado: " . htmlspecialchars($user->id);
    }
}

// Função para atualizar um usuário
function updateUser($data) {
    if (isset($data['update_id'], $data['new_name'])) {
        $user = User::find($data['update_id']);
        if ($user) {
            $user->name = $data['new_name'];
            $user->save();
            echo "Usuário atualizado!";
        } else {
            echo "Usuário não encontrado!";
        }
    }
}

// Função para deletar um usuário
function deleteUser($id) {
    $user = User::find($id);
    if ($user) {
        $user->delete();
        echo "Usuário deletado!";
    } else {
        echo "Usuário não encontrado!";
    }
}

// Exibir usuários
displayUsers();
?>

<!-- Formulários para criar, atualizar e deletar usuários -->
<h2>Criar Usuário</h2>
<form method="POST">
    Nome: <input type="text" name="name" required><br>
    Email: <input type="email" name="email" required><br>
    Senha: <input type="password" name="password" required><br>
    <input type="hidden" name="action" value="create">
    <button type="submit">Criar</button>
</form>

<h2>Atualizar Usuário</h2>
<form method="POST">
    ID do Usuário: <input type="text" name="update_id" required><br>
    Novo Nome: <input type="text" name="new_name" required><br>
    <input type="hidden" name="action" value="update">
    <button type="submit">Atualizar</button>
</form>

<h2>Deletar Usuário</h2>
<form method="POST">
    ID do Usuário: <input type="text" name="delete_id" required><br>
    <input type="hidden" name="action" value="delete">
    <button type="submit">Deletar</button>
</form>
