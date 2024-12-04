<?php

namespace App\Http\Controllers;

// Importação dos modelos
use App\Models\Vaga; 
use App\Models\VagaOcupada;
use App\Models\Pagamento;
use Illuminate\Http\Request;

class VagaController extends Controller
{

        public function index()
    {
        $vaga = Vaga::all();
        return response()->json($vaga);
    }

    public function show($id)
    {
        $vaga = Vaga::find($id);
        
        if (!$vaga) {
            return response()->json(['message' => 'Vaga não encontrada'], 404);
        }
        
        return response()->json($vaga);
    }

    public function store(Request $request)
    {

        //$limiteDeVagas = 100;
        //$totalVagas = Vaga::count();

        //if ($totalVagas >= $limiteDeVagas) {
            //return response()->json(['error' => 'Limite máximo de vagas atingido'], 400);
        //}

        $request->validate([
            'tipo' => 'required|in:comum,deficiente',
            'status' => 'required|in:disponivel,ocupada',
        ]);

        $vaga = Vaga::create([
            'tipo' => $request->tipo,
            'status' => 'disponivel',
        ]);

        return response()->json($vaga, 201); 
    }


    public function destroy($id)
    {
        $vaga = Vaga::find($id);
        
        if (!$vaga) {
            return response()->json(['message' => 'Vaga não encontrada'], 404);
        }

        if ($vaga->status === 'ocupada') {
            return response()->json(['message' => 'Nao eh possivel deletar a vaga enquanto estiver ocupada'], 400);
        }
        
        $vaga->delete();

        return response()->json(['message' => 'Vaga excluida com sucesso']);
    }

    public function updateTipo(Request $request, $id)
    {
        // Validação para garantir que o tipo seja "comum" ou "deficiente"
        $request->validate([
            'tipo' => 'required|in:comum,deficiente', // tipo válido apenas se for "comum" ou "deficiente"
        ]);
    
        // Encontrar a vaga com o ID fornecido
        $vaga = Vaga::find($id);
    
        // Verificar se a vaga existe
        if (!$vaga) {
            return response()->json(['error' => 'Vaga não encontrada'], 404);
        }
    
        // Verificar se o tipo fornecido já é o tipo atual da vaga
        if ($vaga->tipo === $request->tipo) {
            return response()->json(['message' => 'A vaga já é do tipo ' . $request->tipo], 400);
        }
    
        // Atualizar o tipo da vaga
        $vaga->tipo = $request->tipo;
        $vaga->save();
    
        // Retornar a vaga atualizada
        return response()->json(['message' => 'Tipo da vaga alterado com sucesso!', 'vaga' => $vaga], 200);
    }
    

}
