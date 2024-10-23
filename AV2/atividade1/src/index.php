<?php

require 'bootstrap.php';
require 'User.php';

// READ
function getUsers() {
    return User::all();
}

// CREATE
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action']) && $_POST['action'] === 'create') {
    $user = User::create([
        'name' => $_POST['name'],
        'email' => $_POST['email'],
        'password' => password_hash($_POST['password'], PASSWORD_DEFAULT), // Criptografar senha
    ]);
    echo json_encode(['status' => 'success', 'id' => $user->id]);
    exit;
}

// UPDATE
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action']) && $_POST['action'] === 'update') {
    $user = User::find($_POST['update_id']);
    if ($user) {
        $user->name = $_POST['new_name'];
        $user->save();
        echo json_encode(['status' => 'success', 'id' => $user->id]);
    } else {
        echo json_encode(['status' => 'error', 'message' => 'Usuário não encontrado']);
    }
    exit;
}

// DELETE
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action']) && $_POST['action'] === 'delete') {
    $user = User::find($_POST['delete_id']);
    if ($user) {
        $user->delete();
        echo json_encode(['status' => 'success', 'id' => $user->id]);
    } else {
        echo json_encode(['status' => 'error', 'message' => 'Usuário não encontrado']);
    }
    exit;
}
?>

<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CRUD com PHP e Eloquent</title>
    <!-- Bootstrap CSS -->
    <link href="https://maxcdn.bootstrapcdn.com/bootstrap/4.5.2/css/bootstrap.min.css" rel="stylesheet">
    <script src="https://code.jquery.com/jquery-3.5.1.min.js"></script>
</head>
<body>

<div class="container mt-5">
    <h1>CRUD com PHP e Eloquent</h1>
    
    <!-- Exibir usuários cadastrados -->
    <h2>Usuários cadastrados</h2>
    <div id="userList">
        <?php
        $users = getUsers();
        if (count($users) === 0): ?>
            <div class='alert alert-warning'>Não há usuários cadastrados.</div>
        <?php else: ?>
            <ul class="list-group mb-4">
                <?php foreach ($users as $user): ?>
                    <li class="list-group-item user-item" data-id="<?php echo $user->id; ?>">
                        <?php echo $user->id . " - " . $user->name . " - " . $user->email; ?>
                    </li>
                <?php endforeach; ?>
            </ul>
        <?php endif; ?>
    </div>

    <!-- Formulário para criar usuários -->
    <h2>Criar Usuário</h2>
    <form id="createUserForm" class="mb-4">
        <div class="form-group">
            <label for="name">Nome:</label>
            <input type="text" name="name" class="form-control" required>
        </div>
        <div class="form-group">
            <label for="email">Email:</label>
            <input type="email" name="email" class="form-control" required>
        </div>
        <div class="form-group">
            <label for="password">Senha:</label>
            <input type="password" name="password" class="form-control" required>
        </div>
        <button type="submit" class="btn btn-primary">Criar</button>
    </form>

    <!-- Formulário para atualizar usuários -->
    <h2>Atualizar Usuário</h2>
    <form id="updateUserForm" class="mb-4">
        <div class="form-group">
            <label for="update_id">ID do Usuário:</label>
            <input type="text" name="update_id" class="form-control" required>
        </div>
        <div class="form-group">
            <label for="new_name">Novo Nome:</label>
            <input type="text" name="new_name" class="form-control" required>
        </div>
        <button type="submit" class="btn btn-warning">Atualizar</button>
    </form>

    <!-- Formulário para deletar usuários -->
    <h2>Deletar Usuário</h2>
    <form id="deleteUserForm">
        <div class="form-group">
            <label for="delete_id">ID do Usuário:</label>
            <input type="text" name="delete_id" class="form-control" required>
        </div>
        <button type="submit" class="btn btn-danger">Deletar</button>
    </form>
</div>

<!-- Bootstrap JS e dependências -->
<script src="https://cdn.jsdelivr.net/npm/@popperjs/core@2.9.3/dist/umd/popper.min.js"></script>
<script src="https://maxcdn.bootstrapcdn.com/bootstrap/4.5.2/js/bootstrap.min.js"></script>

<script>
$(document).ready(function() {
    // Criar usuário
    $('#createUserForm').on('submit', function(e) {
        e.preventDefault();
        $.ajax({
            type: 'POST',
            url: '', // URL do arquivo atual
            data: $(this).serialize() + '&action=create',
            success: function(response) {
                const result = JSON.parse(response);
                if (result.status === 'success') {
                    $('#userList').append(`<li class="list-group-item user-item" data-id="${result.id}">${result.id} - ${$('input[name="name"]').val()} - ${$('input[name="email"]').val()}</li>`);
                    $('#createUserForm')[0].reset();
                } else {
                    alert('Erro ao criar usuário');
                }
            }
        });
    });

    // Atualizar usuário
    $('#updateUserForm').on('submit', function(e) {
        e.preventDefault();
        $.ajax({
            type: 'POST',
            url: '', // URL do arquivo atual
            data: $(this).serialize() + '&action=update',
            success: function(response) {
                const result = JSON.parse(response);
                if (result.status === 'success') {
                    const userId = result.id;
                    $(`.user-item[data-id="${userId}"]`).text(`${userId} - ${$('input[name="new_name"]').val()} - ${$(`.user-item[data-id="${userId}"]`).text().split(' - ')[2]}`);
                    $('#updateUserForm')[0].reset();
                } else {
                    alert(result.message);
                }
            }
        });
    });

    // Deletar usuário
    $('#deleteUserForm').on('submit', function(e) {
        e.preventDefault();
        $.ajax({
            type: 'POST',
            url: '', // URL do arquivo atual
            data: $(this).serialize() + '&action=delete',
            success: function(response) {
                const result = JSON.parse(response);
                if (result.status === 'success') {
                    $(`.user-item[data-id="${result.id}"]`).remove();
                    $('#deleteUserForm')[0].reset();
                } else {
                    alert(result.message);
                }
            }
        });
    });
});
</script>
</body>
</html>
