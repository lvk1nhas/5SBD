
DELIMITER $$

CREATE PROCEDURE InserirDados()
BEGIN
    -- 1. Inserindo novos clientes que ainda não estão na base
    INSERT INTO wl_clientes (codigoComprador, nomeComprador, email)
    SELECT DISTINCT codigoComprador, nomeComprador, email
    FROM wl_tempdata 
    WHERE NOT EXISTS (SELECT 1 FROM wl_clientes WHERE codigoComprador = wl_tempdata.codigoComprador);

    -- 2. Inserindo novos pedidos que ainda não existem na tabela de pedidos
    INSERT INTO wl_pedidos (codigoPedido, codigoComprador, dataPedido, valor, status)
    SELECT DISTINCT codigoPedido, codigoComprador, dataPedido, SUM(valor), 'pendente'
    FROM wl_tempdata
    WHERE NOT EXISTS (SELECT 1 FROM wl_pedidos WHERE codigoPedido = wl_tempdata.codigoPedido)
    GROUP BY codigoPedido;

    -- 3. Inserindo novos produtos na tabela de produtos
    INSERT INTO wl_produtos (SKU, UPC, nomeProduto, valor)
    SELECT DISTINCT SKU, UPC, nomeProduto, ROUND(valor / quantidade, 2)
    FROM wl_tempdata 
    WHERE NOT EXISTS (SELECT 1 FROM wl_produtos WHERE SKU = wl_tempdata.SKU);

    -- 4. Inserindo itens de pedido na tabela de itens de pedido
    INSERT INTO wl_itens_pedidos (codigoPedido, SKU, quantidade, valor_unitario)
    SELECT DISTINCT codigoPedido, SKU, quantidade, ROUND(valor / quantidade, 2)
    FROM wl_tempdata 
    WHERE NOT EXISTS (SELECT 1 FROM wl_itens_pedidos WHERE codigoPedido = wl_tempdata.codigoPedido AND SKU = wl_tempdata.SKU);

    -- 5. Inserindo dados de entrega na tabela de entregas
    INSERT INTO wl_entregas (codigoPedido, endereco, CEP, UF, pais, valor)
    SELECT DISTINCT codigoPedido, endereco, CEP, UF, pais, frete
    FROM wl_tempdata 
    WHERE NOT EXISTS (SELECT 1 FROM wl_entregas WHERE codigoPedido = wl_tempdata.codigoPedido);

    -- 6. Inserindo produtos na tabela de estoque, se não existirem
    INSERT INTO wl_estoque (SKU)
    SELECT DISTINCT SKU FROM wl_tempdata
    WHERE NOT EXISTS (SELECT 1 FROM wl_estoque WHERE SKU = wl_tempdata.SKU);

END$$

DELIMITER ;

DELIMITER $$
--
-- Procedimentos
--
CREATE DEFINER=root@localhost PROCEDURE RecarregarEstoque ()   BEGIN

    -- Declaração de variáveis para armazenar os valores do cursor
    DECLARE v_SKU VARCHAR(20);  
    DECLARE v_quantidade INT;  
    DECLARE terminou INT DEFAULT 0; 

    -- Definição do cursor para selecionar dados da tabela temporária
    DECLARE cursor_estoque CURSOR FOR SELECT SKU, quantidade FROM wl_tempdata_estoque;

    -- Manipulador para lidar com o fim do cursor
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET terminou = 1; 

    -- Abrindo o cursor para processar as linhas da tabela temporária
    OPEN cursor_estoque;

    -- Loop que percorre cada linha retornada pelo cursor
    movimentacao_loop:LOOP

        -- Buscando os valores da próxima linha do cursor e atribuindo às variáveis
        FETCH cursor_estoque INTO v_SKU, v_quantidade;

        -- Se o cursor já leu todas as linhas, saio
        IF terminou THEN
            LEAVE movimentacao_loop;  -- Sair do loop quando terminar
        END IF;

        -- Atualizando a quantidade de produtos no estoque
        UPDATE wl_estoque 
        SET quantidade = quantidade + v_quantidade 
        WHERE SKU = v_SKU;

        -- Subtraindo a quantidade de compras processada
        UPDATE wl_compras 
        SET quantidade = quantidade - v_quantidade 
        WHERE SKU = v_SKU;
        
    END LOOP;  -- Fim do loop de processamento

    -- Deletando compras cuja quantidade final seja zero ou negativa
    DELETE FROM wl_compras WHERE quantidade <= 0;

    -- Limpando os dados temporários após o processamento
    -- TRUNCATE TABLE wl_tempdata_estoque;

END$$

DELIMITER ;

DELIMITER $$

DELIMITER $$

CREATE DEFINER=root@localhost PROCEDURE ProcessarItensPedidos ()   
BEGIN
    -- Declarando as variáveis no início da procedure
    DECLARE v_codigoPedido INT;
    DECLARE v_codigoProduto VARCHAR(20);
    DECLARE v_quantidade INT;
    DECLARE pronta INT DEFAULT 0;  -- Indica se o cursor já processou todos os registros
    DECLARE estoqueDisponivel INT; -- Declaração da variável de estoque
    DECLARE quantidadePendente INT; -- Declaração da variável para a quantidade total pendente do produto
    
    -- Cursor para selecionar os itens dos pedidos
    DECLARE cursor_itens CURSOR FOR 
    SELECT codigoPedido, SKU, quantidade 
    FROM wl_itens_pedidos
    WHERE status = 'pendente';  -- Apenas itens pendentes serão processados
    
    -- Handler para quando não houver mais registros no cursor
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET pronta = 1;

    -- Início da transação
    START TRANSACTION;

    -- Abrindo o cursor de itens
    OPEN cursor_itens;

    itens_loop: LOOP
        -- Buscando os dados do cursor
        FETCH cursor_itens INTO v_codigoPedido, v_codigoProduto, v_quantidade;

        IF pronta THEN
            LEAVE itens_loop;
        END IF;

        -- Calcula a quantidade total pendente do produto no estoque
        SELECT SUM(quantidade) INTO quantidadePendente
        FROM wl_itens_pedidos 
        WHERE SKU = v_codigoProduto AND status = 'pendente';

        -- Verifica a quantidade total do item no estoque
        SELECT quantidade INTO estoqueDisponivel
        FROM wl_estoque
        WHERE SKU = v_codigoProduto
        FOR UPDATE;

        -- Verifica se o estoque disponível é suficiente para todos os itens pendentes
        IF quantidadePendente <= estoqueDisponivel THEN
            -- Aprova todos os itens pendentes para esse produto
            UPDATE wl_itens_pedidos 
            SET status = 'aprovado' 
            WHERE SKU = v_codigoProduto AND status = 'pendente';
            
        ELSE
            -- Marca todos os itens pendentes desse produto como pendentes
            UPDATE wl_itens_pedidos 
            SET status = 'pendente' 
            WHERE SKU = v_codigoProduto AND status = 'pendente';

            -- Verifica se o item precisa ser comprado
            IF EXISTS (SELECT 1 FROM wl_compras WHERE SKU = v_codigoProduto) THEN
                UPDATE wl_compras 
                SET quantidade = quantidade + v_quantidade 
                WHERE SKU = v_codigoProduto;
            ELSE
                INSERT INTO wl_compras (SKU, quantidade) 
                VALUES (v_codigoProduto, v_quantidade);
            END IF;
        END IF;
    END LOOP;

    -- Fechando o cursor de itens
    CLOSE cursor_itens;

    -- Commit da transação
    COMMIT;

END$$

DELIMITER ;



DELIMITER $$

CREATE PROCEDURE ProcessarPedidos()
BEGIN
    DECLARE v_codigoPedido VARCHAR(32);
    DECLARE totalItens INT;
    DECLARE totalAprovados INT;
    DECLARE pronto INT DEFAULT 0;

    -- Declara um cursor para selecionar todos os códigos de pedido
    DECLARE cursor_pedidos CURSOR FOR 
    SELECT DISTINCT codigoPedido 
    FROM wl_itens_pedidos;

    -- Manipulador para o final do cursor
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET pronto = 1;

    -- Início da transação
    START TRANSACTION;

    -- Abre o cursor
    OPEN cursor_pedidos;

    pedidos_loop: LOOP
        -- Busca o próximo código de pedido
        FETCH cursor_pedidos INTO v_codigoPedido;

        -- Se o cursor tiver terminado, sai do loop
        IF pronto THEN
            LEAVE pedidos_loop;
        END IF;

        -- Conta o total de itens do pedido
        SELECT COUNT(*) INTO totalItens 
        FROM wl_itens_pedidos 
        WHERE codigoPedido = v_codigoPedido;

        -- Conta o total de itens aprovados do pedido
        SELECT COUNT(*) INTO totalAprovados 
        FROM wl_itens_pedidos 
        WHERE codigoPedido = v_codigoPedido AND status = 'aprovado';

        -- Verifica se todos os itens estão aprovados
        IF totalItens = totalAprovados THEN
            -- Atualiza o status do pedido para aprovado
            UPDATE wl_pedidos 
            SET status = 'aprovado' 
            WHERE codigoPedido = v_codigoPedido;

            -- Chama a procedure para debitar o estoque agora que o pedido foi aprovado
            CALL DebitarEstoquePedido(v_codigoPedido);
        END IF;
    END LOOP;

    -- Fechando o cursor de pedidos
    CLOSE cursor_pedidos;

    -- Commit da transação
    COMMIT;

END$$

DELIMITER ;

DELIMITER $$

CREATE PROCEDURE DebitarEstoquePedido(v_codigoPedido VARCHAR(32))
BEGIN
    DECLARE v_codigoProduto VARCHAR(20);
    DECLARE v_quantidade INT;
    DECLARE pronto INT DEFAULT 0;

    -- Declara um cursor para pegar os itens aprovados do pedido
    DECLARE cursor_itens_pedido CURSOR FOR 
    SELECT SKU, quantidade
    FROM wl_itens_pedidos
    WHERE codigoPedido = v_codigoPedido AND status = 'aprovado';

    -- Manipulador para o final do cursor
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET pronto = 1;

    -- Abre o cursor
    OPEN cursor_itens_pedido;

    itens_pedido_loop: LOOP
        -- Busca os dados do item aprovado
        FETCH cursor_itens_pedido INTO v_codigoProduto, v_quantidade;

        -- Se o cursor não tiver mais itens, sai do loop
        IF pronto THEN
            LEAVE itens_pedido_loop;
        END IF;

        -- Debita o estoque do item aprovado
        UPDATE wl_estoque 
        SET quantidade = quantidade - v_quantidade 
        WHERE SKU = v_codigoProduto;
    END LOOP;

    -- Fechando o cursor
    CLOSE cursor_itens_pedido;

END$$

DELIMITER ;
