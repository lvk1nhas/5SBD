<?php

namespace App\Http\Controllers;

// Importação dos modelos
use App\Models\Vaga; 
use App\Models\VagaOcupada;
use App\Models\Pagamento;
use Illuminate\Http\Request;
use Carbon\Carbon;

class VagaOcupadaController extends Controller
{


    public function ocupar(Request $request, $vagaId)
{
    $request->validate([
        'placa' => 'required|string|max:7',
    ]);

    $vaga = Vaga::find($vagaId);

    if (!$vaga) {
        return response()->json(['error' => 'Vaga não encontrada'], 404);
    }

    if ($vaga->status !== 'disponivel') {
        return response()->json(['error' => 'Vaga já está ocupada'], 400);
    }

    $existePlacaOcupada = VagaOcupada::where('placa', $request->placa)
        ->whereNull('horario_saida') // Verifica se a placa já está ocupando uma vaga
        ->exists();

    if ($existePlacaOcupada) {
        return response()->json(['error' => 'Essa placa já está ocupando outra vaga.'], 400);
    }

    // Atualiza o status da vaga
    $vaga->status = 'ocupada';
    $vaga->save();

    // Cria o registro em `vaga_ocupada`
    $vagaOcupada = VagaOcupada::create([
        'vaga_id' => $vaga->id,
        'placa' => $request->placa,
        'horario_entrada' => now(),
        'preco' => 0,
    ]);

    return response()->json(['message' => 'Vaga ocupada com sucesso!', 'vaga_ocupada' => $vagaOcupada], 201);
}

public function desocupar(Request $request, $vagaId)
{
    $vaga = Vaga::find($vagaId);

    if (!$vaga) {
        return response()->json(['error' => 'Vaga não encontrada'], 404);
    }

    if ($vaga->status !== 'ocupada') {
        return response()->json(['error' => 'A vaga já está disponível'], 400);
    }

    // Busca o registro de `vaga_ocupada` correspondente
    $vagaOcupada = VagaOcupada::where('vaga_id', $vaga->id)
        ->whereNull('horario_saida')
        ->first();

    if (!$vagaOcupada) {
        return response()->json(['error' => 'Registro de vaga ocupada não encontrado'], 400);
    }

    // Chamar o método calcularPreco para obter o preço
    $precoCalculado = $vagaOcupada->calcularPreco();
    $vagaOcupada->preco = $precoCalculado;
    $vagaOcupada->save();


    // Registra o pagamento com o status 'pendente'
    Pagamento::create([
        'vaga_id' => $vagaOcupada->vaga_id,
        'preco' => $vagaOcupada->preco,
        'status' => 'pendente',
        'placa' => $vagaOcupada->placa,
    ]);

    // Remove o registro de `vaga_ocupada` e atualiza a vaga como disponível
    $vagaOcupada->delete();
    $vaga->status = 'disponivel';
    $vaga->save();

    return response()->json(['message' => 'Vaga desocupada com sucesso e disponível para uso!', 'preco' => $vagaOcupada->preco]);
}


public function listarVagaOcupada()
{
    // Buscar todas as vagas ocupadas, incluindo a relação com a tabela 'vaga'.
    $vagaOcupada = VagaOcupada::with('vaga')->get();

    // Verificar se não há vagas ocupadas
    if ($vagaOcupada->isEmpty()) {
        // Retornar uma resposta com uma mensagem de erro ou uma notificação de que não há vagas ocupadas
        return response()->json(['message' => 'Nenhuma vaga ocupada no momento.'], 200);
    }

    // Caso haja vagas ocupadas, retornar os dados encontrados
    return response()->json($vagaOcupada);
}

}
