CREATE DEFINER=root@localhost PROCEDURE ProcessarItensPedidos ()   
BEGIN
    DECLARE v_codigoPedido INT;
    DECLARE v_codigoProduto VARCHAR(20);
    DECLARE v_quantidade INT;
    DECLARE pronto INT DEFAULT 0;  -- Indica se o cursor já processou todos os registros

    -- Cursor para selecionar os itens dos pedidos
    DECLARE cursor_itens CURSOR FOR 
    SELECT codigoPedido, SKU, quantidade 
    FROM wl_itens_pedidos
    WHERE status = 'pendente';  -- Apenas itens pendentes serão processados
    
    -- Handler para quando não houver mais registros no cursor
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET pronto = 1;

    -- Abrindo o cursor de itens
    OPEN cursor_itens;

    itens_loop: LOOP
        -- Buscando os dados do cursor
        FETCH cursor_itens INTO v_codigoPedido, v_codigoProduto, v_quantidade;

        IF pronto THEN
            LEAVE itens_loop;
        END IF;

        -- Verifica se há quantidade suficiente em estoque
        IF (SELECT quantidade FROM wl_estoque WHERE SKU = v_codigoProduto) >= v_quantidade THEN
            -- Aprova o item e ajusta o estoque
            UPDATE wl_itens_pedidos 
            SET status = 'aprovado' 
            WHERE codigoPedido = v_codigoPedido AND SKU = v_codigoProduto;

            UPDATE wl_estoque 
            SET quantidade = quantidade - v_quantidade 
            WHERE SKU = v_codigoProduto;
        ELSE
            -- Marca o item como pendente e insere ou atualiza a solicitação de compra
            UPDATE wl_itens_pedidos 
            SET status = 'pendente' 
            WHERE codigoPedido = v_codigoPedido AND SKU = v_codigoProduto;

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

END$$

DELIMITER ;
