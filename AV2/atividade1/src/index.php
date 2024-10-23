<?php 

require 'bootstrap.php';
require 'User.php';

$users = []; // Inicializa a variável

try {
    // READ: Carrega todos os usuários
    $users = User::all();

    // CREATE
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['name'], $_POST['email'], $_POST['password'])) {
        User::createUser($_POST);
        header("Location: index.php");
        exit; // Redireciona após criar
    }

    // UPDATE
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['update_id'], $_POST['new_name'], $_POST['new_email'])) {
        $user = User::find($_POST['update_id']);
        if ($user) {
            $user->updateUser(['name' => $_POST['new_name'], 'email' => $_POST['new_email']]);
            header("Location: index.php");
            exit;
        } else {
            echo "Usuário não encontrado!";
        }
    }

    // DELETE
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['delete_id'])) {
        $user = User::find($_POST['delete_id']);
        if ($user) {
            $user->deleteUser();
            header("Location: index.php");
            exit;
        } else {
            echo "Usuário não encontrado!";
        }
    }

} catch (Exception $e) {
    echo $e->getMessage();
}

// Exibir usuários cadastrados
echo "<h2>Usuários cadastrados</h2>";
foreach ($users as $user) {
    echo $user->id . " - " . $user->name . " - " . $user->email . "<br>";
}

// Formulários...
?>

<!-- Formulários para criar, atualizar e deletar usuários -->
<h2>Criar Usuário</h2>
<form method="POST">
    Nome: <input type="text" name="name" required><br>
    Email: <input type="email" name="email" required><br>
    Senha: <input type="password" name="password" required><br>
    <button type="submit">Criar</button>
</form>

<h2>Atualizar Usuário</h2>
<form method="POST">
    ID do Usuário: <input type="text" name="update_id" required><br>
    Novo Nome: <input type="text" name="new_name" required><br>
    Novo Email: <input type="email" name="new_email" required><br>
    <button type="submit">Atualizar</button>
</form>

<h2>Deletar Usuário</h2>
<form method="POST">
    ID do Usuário: <input type="text" name="delete_id" required><br>
    <button type="submit">Deletar</button>
</form>
