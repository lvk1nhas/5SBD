<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

use App\Http\Controllers\VagaController;
use App\Http\Controllers\VagaOcupadaController;
use App\Http\Controllers\PagamentoController;

//rota vagas
Route::get('/vagas', [VagaController::class, 'index']);
Route::get('/vagas/{id}', [VagaController::class, 'show']);
Route::post('/vagas', [VagaController::class, 'store']);
Route::put('/vagas/{id}/tipo', [VagaController::class, 'updateTipo']);
Route::delete('/vagas/{id}', [VagaController::class, 'destroy']);


//rota vagas ocupadas
Route::get('/vaga-ocupada', [VagaOcupadaController::class, 'listarVagaOcupada']);
Route::post('/vaga-ocupada/{id}/ocupar', [VagaOcupadaController::class, 'ocupar']);
Route::put('/vaga-ocupada/{id}/desocupar', [VagaOcupadaController::class, 'desocupar']);

//rota pagamentos
Route::get('/pagamentos', [PagamentoController::class, 'index']);
Route::put('/pagamentos/{id}/pagar', [PagamentoController::class, 'pagar']); 


Route::middleware('auth:sanctum')->get('/user', function (Request $request) {
    return $request->user();
});
