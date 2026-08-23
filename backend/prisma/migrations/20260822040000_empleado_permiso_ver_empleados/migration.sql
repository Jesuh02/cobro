INSERT INTO recurso (codigo, nombre) VALUES
  ('VER_EMPLEADOS', 'Ver empleados')
ON CONFLICT (codigo) DO UPDATE
SET nombre = EXCLUDED.nombre,
    actualizado_en = now();

INSERT INTO rol (codigo, nombre) VALUES
  ('VER_EMPLEADOS', 'Permiso ver empleados')
ON CONFLICT (codigo) DO UPDATE
SET nombre = EXCLUDED.nombre;

INSERT INTO rol_recurso (rol_id, recurso_id)
SELECT r.rol_id, rec.recurso_id
FROM rol r
JOIN recurso rec ON rec.codigo = r.codigo
WHERE r.codigo = 'VER_EMPLEADOS'
ON CONFLICT DO NOTHING;

INSERT INTO rol_recurso (rol_id, recurso_id)
SELECT admin.rol_id, rec.recurso_id
FROM rol admin
JOIN recurso rec ON rec.codigo = 'VER_EMPLEADOS'
WHERE admin.codigo = 'ADMINISTRADOR'
ON CONFLICT DO NOTHING;
