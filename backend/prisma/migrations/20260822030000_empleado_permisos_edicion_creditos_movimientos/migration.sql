INSERT INTO recurso (codigo, nombre) VALUES
  ('MODIFICAR_CREDITOS', 'Modificar creditos'),
  ('ELIMINAR_CREDITOS', 'Eliminar creditos'),
  ('MODIFICAR_MOVIMIENTOS', 'Modificar movimientos'),
  ('ELIMINAR_MOVIMIENTOS', 'Eliminar movimientos')
ON CONFLICT (codigo) DO UPDATE
SET nombre = EXCLUDED.nombre,
    actualizado_en = now();

INSERT INTO rol (codigo, nombre) VALUES
  ('MODIFICAR_CREDITOS', 'Permiso modificar creditos'),
  ('ELIMINAR_CREDITOS', 'Permiso eliminar creditos'),
  ('MODIFICAR_MOVIMIENTOS', 'Permiso modificar movimientos'),
  ('ELIMINAR_MOVIMIENTOS', 'Permiso eliminar movimientos')
ON CONFLICT (codigo) DO UPDATE
SET nombre = EXCLUDED.nombre;

INSERT INTO rol_recurso (rol_id, recurso_id)
SELECT r.rol_id, rec.recurso_id
FROM rol r
JOIN recurso rec ON rec.codigo = r.codigo
WHERE r.codigo IN (
  'MODIFICAR_CREDITOS',
  'ELIMINAR_CREDITOS',
  'MODIFICAR_MOVIMIENTOS',
  'ELIMINAR_MOVIMIENTOS'
)
ON CONFLICT DO NOTHING;

INSERT INTO rol_recurso (rol_id, recurso_id)
SELECT admin.rol_id, rec.recurso_id
FROM rol admin
JOIN recurso rec ON rec.codigo IN (
  'MODIFICAR_CREDITOS',
  'ELIMINAR_CREDITOS',
  'MODIFICAR_MOVIMIENTOS',
  'ELIMINAR_MOVIMIENTOS'
)
WHERE admin.codigo = 'ADMINISTRADOR'
ON CONFLICT DO NOTHING;
