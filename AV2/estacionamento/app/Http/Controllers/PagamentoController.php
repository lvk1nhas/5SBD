<?php

namespace App\Http\Controllers;

// Importação dos modelos
use App\Models\Pagamento;
use App\Models\Vaga;
use App\Models\VagaOcupada;
use Illuminate\Http\Request;

class PagamentoController extends Controller
{
    public function pagar(Request $request, $id)
    {
        // Encontra o pagamento pela ID
        $pagamento = Pagamento::findOrFail($id);
    
        // Verifica se o pagamento já foi realizado
        if ($pagamento->status === 'pago') {
            return response()->json(['message' => 'Pagamento ja realizado'], 400);
        }
    
        // Encontra a vaga associada ao pagamento
        $vaga = $pagamento->vaga; 
    
        // Verifica se a vaga existe
        if (!$vaga) {
            return response()->json(['error' => 'Vaga associada nao encontrada'], 400);
        }
    
        // Atualiza o status do pagamento para 'pago'
        $pagamento->update([
            'status' => 'pago',
        ]);
        
        // Atualiza a vaga para disponível
        $vaga->update(['status' => 'disponivel']);
    
        return response()->json(['message' => 'Pagamento realizado, tenha um bom dia!'], 200);
    }
    

    public function index()
    {
        $pagamentos = Pagamento::all(); 
        return response()->json($pagamentos); 
    }

}
