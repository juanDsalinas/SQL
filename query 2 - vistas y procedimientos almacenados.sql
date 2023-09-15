Use neptunedb;
-------------------------------------------- 1 --------------------------------------------------------
create view VwProductoDetails as 
select p.idProducto, p.nombreProducto, c.idCategoria, c.nombreCategoria, dp.cantidad from producto as p inner join detalles_de_pedido as dp
on p.idProducto=dp.idProducto inner join categoria as c on p.idCategoria=c.idCategoria group by p.idProducto;

delimiter //
create procedure spProductDetails(in id int)
begin
	select nombreProducto, cantidad from VwProductoDetails where idCategoria = id;
end; 
//

call spProductDetails(1);

-------------------------------------------- 2 --------------------------------------------------------
create view VwDetailsEmpleado as
select e.nombre, e.apellidos, (2023-year(fechaNacimiento)) as edad, (dp.precioUnidad*dp.cantidad) as totalVentas from empleado as e inner join pedido as p on p.idEmpleado=e.idEmpleado
inner join detalles_de_pedido as dp on dp.idPedido=p.idPedido where e.idEmpleado=p.idEmpleado group by e.idEmpleado;

delimiter //
create procedure spDetailsEmpleado(in valor int)
begin
	select * from VwDetailsEmpleado where totalVentas>valor; 
end;
//

call spDetailsEmpleado(200);
-------------------------------------------- 3 --------------------------------------------------------

create view VwDetailsProduct as 
select c.nombreCategoria, p.nombreProducto, pro.idProveedor, pro.nombreEmpresa, p.cantidadPorUnidad from categoria as c
inner join producto as p on p.idCategoria=c.idCategoria
inner join proveedor as pro on p.idProveedor=pro.idProveedor;

select * from VwDetailsProduct;

delimiter //
create procedure spDetailsProduct(in id int)
begin
	select * from VwDetailsProduct where idProveedor=id;
end;
//

call spDetailsProduct(1);

-------------------------------------------- 4 --------------------------------------------------------
create view VwClienteDetails (idCliente, nombreEmpresa,totalPrecio,fechaPedido) as
select c.idCliente, c.nombreEmpresa, (dp.cantidad*dp.precioUnidad) as totalPrecio, Month(p.fechaPedido) from cliente as c inner join pedido as p on p.idCliente=c.idCliente
inner join detalles_de_pedido as dp on dp.idPedido=p.idPedido order by c.idCliente and  Month(p.fechaPedido);

drop view VwClienteDetails;

select * from VwClienteDetails;

delimiter //
create procedure ClienteDetails(in fechaInicial date, fechaFinal date)
begin	
	select * from VwClienteDetails where fechaPedido between fechaInicial and fechaFinal;
end;
//

call ClienteDetails(3,6);
-------------------------------------------- 5 --------------------------------------------------------
CREATE VIEW VistaPorcentajePago (codigoCliente,nombreCompania,porcentaje_pago)AS
SELECT
    IdCliente,
    NombreEmpresa,
    (totalPrecio / totalVentas) * 100 AS porcentaje_pago
FROM (
    SELECT
        vws.IdCliente,
        vws.NombreEmpresa,
        vws.totalPrecio,
        (SELECT SUM(totalPrecio) FROM VwClienteDetails) AS totalVentas
    FROM VwClienteDetails vws
) AS subconsulta;

DELIMITER //
CREATE PROCEDURE SP_ClientesPorcentajeMayor(IN porcentaje_mayor FLOAT)
BEGIN
    SELECT
        codigoCliente,
        nombreCompania,
        porcentaje_pago
    FROM
        VistaPorcentajePago
    WHERE
        porcentaje_pago > porcentaje_mayor;
END;
//
DELIMITER ;

CALL SP_ClientesPorcentajeMayor(0.01); -- Esto mostrará los clientes con un porcentaje de pago mayor al 30%

-------------------------------------------- 6 --------------------------------------------------------
CREATE VIEW vista_productoV2 AS 
SELECT * FROM producto WHERE PrecioUnidad > 20 
with check option; 

DELIMITER //
CREATE PROCEDURE spInsertarProducto(in id_Producto int,IN nombre_producto VARCHAR(80), IN precio_unidad FLOAT)
BEGIN
    INSERT INTO producto (idProducto,NombreProducto, PrecioUnidad)
    VALUES (id_Producto,nombre_producto, precio_unidad);
END;
//
DELIMITER ;

CALL spInsertarProducto(1010,'Suavitel', 30);

/*se realiza el registro pero nos devuelve una alerta ya que solo se inserta el id del producto y el nombre del producto*/

DELIMITER // 
CREATE PROCEDURE SP_modificarProduV2(codProducto int, precio float) 
BEGIN 
	SET @PrecioActual = (SELECT PrecioUnidad FROM vista_productoV2 WHERE idProducto = codProducto); 
    IF precio between @PrecioActual * 0.95 AND @PrecioActual * 1.05 THEN 
		UPDATE vista_productoV2 SET PrecioUnidad = precio WHERE idProducto = codProducto; 
	ELSE  
		signal sqlstate '45000' SET message_text = 'EL PRECIO NO PUEDE INCREMNETAR NI DRECREMENTAR MÁS DEL 5% DEL PRECIO ORIGINAL'; 
    END IF; 
END; 
//

call SP_modificarProduV2(4,23.0);
-------------------------------------------- 7 --------------------------------------------------------
-- El funcionamiento de la clausula distinct es muy sencillo, lo que busca esta clausula es permitir que en la consulta se eliminen duplicados
-- y de esta manera solo se mostraran aquellos datos que sean unicos
create view RegionesClienteView
as
select distinct Region from cliente
where Region is not null;

select * from RegionesClienteView;
-------------------------------------------- 8 --------------------------------------------------------
-- Procedimiento almacenado para inactivar o suspender productos 

DELIMITER //
create procedure SPSuspendeProductos(IN CodigoProducto int)
begin 
	-- variable de cantidades en pedido
    declare UnidadEnPedido int;
    -- variable de mensaje de error
    declare ErrorExistencias varchar (70);
    -- Asignacion de cantidad de existencias
    set UnidadEnPedido = (select UnidadesEnExistencia from producto where IdProducto = CodigoProducto);
    
    if UnidadEnPedido = 0 then 
		update producto 
        set Suspendido = 1
        where IdProducto = CodigoProducto
        ;
        select IdProducto, NombreProducto, Suspendido 
        from producto
        where IdProducto=CodigoProducto;
    else 
		set ErrorExistencias = 'La cantidad de existencias es mayor o menor a 0 y no se puede suspender';
		select ErrorExistencias;
	end if;
    
end; 
//

call SPSuspendeProductos(10);

----------------------------------------------------------------------------------------------------------------------------------------------
Use neptunedb;
----------------------------------------------------------------------------------------------------------------------------------------------

create table RegistroEnvios
 (IdRegEnvio int AUTO_INCREMENT primary key,
  NumPedido int not null,
  fechaEntrega datetime,
  CodEmpEnvio int,
  CargoPedido float,
  CiudadDestino varchar(15))

delimiter //
Create TRIGGER InsTransCarga
AFTER INSERT ON pedido 
FOR EACH ROW 
BEGIN 
insert into registroenvios(NumPedido, fechaEntrega, CodEmpEnvio, CargoPedido, CiudadDestino) 
Values (new.IdPedido, new.FechaEntrega, new.IdEmpresasTransporte, new.Cargo, new.CiudadDestinatario); 
END;
//


INSERT INTO `pedido` (`IdPedido`, `IdCliente`, `IdEmpleado`, `FechaPedido`, `FechaEntrega`, `FechaEnvio`, `IdEmpresasTransporte`, `Cargo`, 
`Destinatario`, `DireccionDestinatario`, `CiudadDestinatario`, `RegionDestinatario`, `CodPostalDestinatario`, `PaisDestinatario`)
VALUES ('11079', 'ALFKI', '5', '2022-08-30', '2022-08-30', '2022-08-30', '3', '12', 'no aplica', 'no aplica', 'bogota', 'bogota', '17', 'Colombia');


select * from pedido where idPedido='11079';
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------
create table ModificarPrecio
 (IdModificacion int AUTO_INCREMENT primary key,
  CodProducto int not null,
  PrecioProducto FLOAT,
  PrecioNuevo FLOAT,
  Fecha DATETIME DEFAULT CURRENT_DATE(),
  Usuario varchar(50) default USER()
  )

DELIMITER //
CREATE TRIGGER DisminuirPrecio
BEFORE UPDATE ON Producto FOR EACH ROW
BEGIN
		INSERT into ModificarPrecio (CodProducto, PrecioProducto, PrecioNuevo, fecha, usuario)
		VALUES(OLD.IdProducto, OLD.PrecioUnidad, NEW.PrecioUnidad, now() ,user() );
  END;
 //
 
 drop trigger DisminuirPrecio;

update Producto
  set PrecioUnidad = preciounidad+(PrecioUnidad*1/100)
  where IdProducto=2;

select * from producto where idProducto=2;
select * from ModificarPrecio;

select * from ModificarPrecio m inner join Producto p on m.CodProducto=p.IdProducto;
----------------------------------------------------------------------------------------------------------------------------------------------
/*Trigger # 1*/
DELIMITER //
CREATE TRIGGER modificarCargoPedido
BEFORE UPDATE ON pedido
FOR EACH ROW
BEGIN
    IF NEW.Cargo < OLD.Cargo THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No se permite reducir el cargo del pedido.';
    END IF;
END;
//

select * from pedido;
update pedido set cargo=34 where idPedido=10248;
/*drop trigger modificarCargoPedido;*/
-------------------------------------------------------------------------------------------------------------------------------------------------------
/*Trigger # 2*/
delimiter //
create trigger modificarFechaVinculacion
before update on empleado
for each row
begin
	if new.fechaContratación < old.fechaContratación then
		SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No se permite cambiar la fecha de vinculacion del empleado por una menor.';
	end if;
end;
//

select * from empleado;

update empleado set fechaContratación='1993-05-03'where idEmpleado=1;
update empleado set fechaContratación='1993-05-01'where idEmpleado=1;
-------------------------------------------------------------------------------------------------------------------------------------------------------
/*trigger # 3*/
DELIMITER //
CREATE TRIGGER impedirBorrarDetallesDePedido
BEFORE DELETE ON detalles_de_pedido
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
    SET MESSAGE_TEXT = 'No se permite borrar detalles de pedidos.';
END;
//
DELIMITER ;

select * from detalles_de_pedido;
delete from detalles_de_pedido where idDetalle=1;
