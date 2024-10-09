DELIMITER //
CREATE PROCEDURE wl_processar_pedidos_v2()
BEGIN

    -- Variáveis usadas para armazenar os valores dos pedidos e seus itens
    DECLARE v_codigoPedido INT;
    DECLARE v_statusPedido VARCHAR(20);
    DECLARE v_codigoProduto VARCHAR(20);
    DECLARE v_quantidade INT;
    DECLARE pronto INT DEFAULT 0;  -- Indica se o cursor já processou todos os registros

    -- Cursores para os pedidos e itens de pedidos
    DECLARE cursor_pedidos CURSOR FOR SELECT codigoPedido, status FROM wl_pedidos;
    DECLARE cursor_itens CURSOR FOR SELECT SKU, quantidade FROM wl_itens_pedidos;
    
    -- Handler para quando o cursor não encontrar mais registros
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET pronto = 1;

    -- 1. Inserindo novos clientes que ainda não estão na base
    INSERT INTO wl_clientes (codigoComprador, nomeComprador, email)
    SELECT DISTINCT codigoComprador, nomeComprador, email
    FROM wl_tempdata 
    WHERE NOT EXISTS (SELECT 1 FROM wl_clientes WHERE codigoComprador = wl_tempdata.codigoComprador);

    -- 2. Inserindo novos pedidos que ainda não existem na tabela de pedidos
    INSERT INTO wl_pedidos (codigoPedido, codigoComprador, dataPedido, valor, status)
    SELECT DISTINCT codigoPedido, codigoComprador, dataPedido, valor, 'pendente'
    FROM wl_tempdata 
    WHERE NOT EXISTS (SELECT 1 FROM wl_pedidos WHERE codigoPedido = wl_tempdata.codigoPedido);

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

    -- Limpar a tabela temporária de dados
    TRUNCATE TABLE wl_tempdata;

    -- Abrir o cursor de pedidos
    OPEN cursor_pedidos;

    -- Loop principal para processar os pedidos pendentes
    pedidos_loop: LOOP

        -- Buscar os dados do próximo pedido
        FETCH cursor_pedidos INTO v_codigoPedido, v_statusPedido;

        -- Se o cursor não encontrar mais registros, saia do loop
        IF NOT pronto THEN

            -- Verificar o status do pedido
            IF v_statusPedido = 'pendente' THEN

                -- Abrir o cursor para itens do pedido
                OPEN cursor_itens;

                -- Loop para processar os itens do pedido
                itens_loop: LOOP
                    -- Buscar dados do item
                    FETCH cursor_itens INTO v_codigoProduto, v_quantidade;

                    -- Se não houver mais itens, sair do loop
                    IF pronto THEN
                        LEAVE itens_loop;
                    END IF;

                    -- Verificar a disponibilidade no estoque
                    IF (SELECT quantidade FROM wl_estoque WHERE SKU = v_codigoProduto) >= v_quantidade THEN
                        -- Atualizar o status do item e diminuir o estoque
                        UPDATE wl_itens_pedidos SET status = 'aprovado' WHERE codigoPedido = v_codigoPedido AND SKU = v_codigoProduto;
                        UPDATE wl_estoque SET quantidade = quantidade - v_quantidade WHERE SKU = v_codigoProduto;
                    ELSE
                        -- Caso o estoque não seja suficiente, marcar como pendente
                        UPDATE wl_pedidos SET status = 'pendente' WHERE codigoPedido = v_codigoPedido;
                        UPDATE wl_itens_pedidos SET status = 'pendente' WHERE codigoPedido = v_codigoPedido AND SKU = v_codigoProduto;

                        -- Se o produto já estiver na lista de compras, atualizar a quantidade
                        IF EXISTS (SELECT 1 FROM wl_compras WHERE SKU = v_codigoProduto) THEN
                            UPDATE wl_compras SET quantidade = quantidade + v_quantidade WHERE SKU = v_codigoProduto;
                        ELSE
                            -- Caso contrário, inserir o produto na lista de compras
                            INSERT INTO wl_compras (SKU, quantidade) VALUES (v_codigoProduto, v_quantidade);
                        END IF;
                    END IF;
                END LOOP;

                -- Fechar o cursor de itens após processar todos
                CLOSE cursor_itens;

                -- Se todos os itens foram aprovados, aprovar o pedido
                IF NOT EXISTS (SELECT 1 FROM wl_itens_pedidos WHERE codigoPedido = v_codigoPedido AND status = 'pendente') THEN
                    UPDATE wl_pedidos SET status = 'aprovado' WHERE codigoPedido = v_codigoPedido;
                END IF;
            END IF;
        ELSE
            -- Sair do loop se o cursor não encontrar mais registros
            LEAVE pedidos_loop;
        END IF;
    END LOOP;

    -- Fechar o cursor de pedidos
    CLOSE cursor_pedidos;

END//
DELIMITER ;
