CREATE PROCEDURE ProcessarPedidos()
BEGIN
    DECLARE v_codigoPedido VARCHAR(32);
    DECLARE v_statusPedido VARCHAR(20);
    DECLARE totalItens INT;
    DECLARE totalAprovados INT;
    DECLARE pronto INT DEFAULT 0;

    -- Declara um cursor para selecionar todos os códigos de pedido
    DECLARE cursor_pedidos CURSOR FOR 
    SELECT DISTINCT codigoPedido 
    FROM wl_itens_pedidos;

    -- Manipulador para o final do cursor
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET pronto = 1;

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
        END IF;
    END LOOP;

    -- Fecha o cursor
    CLOSE cursor_pedidos;
END$$

DELIMITER ;
