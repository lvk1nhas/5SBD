<?php

require 'bootstrap.php';
require 'User.php';

// CREATE
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['name'], $_POST['email'], $_POST['password'])) {
    $user = User::create([
        'name' => $_POST['name'],
        'email' => $_POST['email'],
        'password' => password_hash($_POST['password'], PASSWORD_DEFAULT), // Criptografar senha
    ]);
    echo "Usuário criado: " . $user->id;
}

// READ
$users = User::all();
echo "<h2>Usuários cadastrados</h2>";
foreach ($users as $user) {
    echo $user->id . " - " . $user->name . " - " . $user->email . "<br>";
}

// UPDATE
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['update_id'], $_POST['new_name'])) {
    $user = User::find($_POST['update_id']);
    if ($user) {
        $user->name = $_POST['new_name'];
        $user->save();
        echo "Usuário atualizado!";
    }
}

// DELETE
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['delete_id'])) {
    $user = User::find($_POST['delete_id']);
    if ($user) {
        $user->delete();
        echo "Usuário deletado!";
    }
}
?>

<!-- Formulários para criar, atualizar e deletar usuários -->
<h2>Criar Usuário</h2>
<form method="POST">
    Nome: <input type="text" name="name"><br>
    Email: <input type="email" name="email"><br>
    Senha: <input type="password" name="password"><br>
    <button type="submit">Criar</button>
</form>

<h2>Atualizar Usuário</h2>
<form method="POST">
    ID do Usuário: <input type="text" name="update_id"><br>
    Novo Nome: <input type="text" name="new_name"><br>
    <button type="submit">Atualizar</button>
</form>

<h2>Deletar Usuário</h2>
<form method="POST">
    ID do Usuário: <input type="text" name="delete_id"><br>
    <button type="submit">Deletar</button>
</form>
