<?php

require 'bootstrap.php';
require 'UserController.php';

$controller = new UserController();
$users = []; // Inicializa a variável

try {
    // READ: Carrega todos os usuários
    $users = $controller->index();

    // CREATE
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['name'], $_POST['email'], $_POST['password'])) {
        $controller->create($_POST);
        header("Location: index.php");
        exit; // Redireciona após criar
    }

    // UPDATE
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['update_id'], $_POST['new_name'], $_POST['new_email'])) {
        $controller->update($_POST['update_id'], [
            'name' => $_POST['new_name'],
            'email' => $_POST['new_email']
        ]);
        header("Location: index.php");
        exit;
    }

    // DELETE
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['delete_id'])) {
        $controller->delete($_POST['delete_id']);
        header("Location: index.php");
        exit;
    }

} catch (Exception $e) {
    echo $e->getMessage(); // Exibe a mensagem de erro
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
