CREATE TABLE IF NOT EXISTS public.tbl_usuarios_organizaciones_recursos (
  id_uor uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  urg_id uuid NOT NULL,
  rec_id uuid NOT NULL,
  uor_creacion timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_uor_usuario_organizacion
    FOREIGN KEY (urg_id)
    REFERENCES public.tbl_usuarios_organizaciones (id_urg)
    ON DELETE CASCADE,
  CONSTRAINT fk_uor_recurso
    FOREIGN KEY (rec_id)
    REFERENCES public.tbl_recursos (id_rec)
    ON DELETE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_tbl_usuarios_organizaciones_recursos
  ON public.tbl_usuarios_organizaciones_recursos (urg_id, rec_id);

CREATE INDEX IF NOT EXISTS ix_tbl_usuarios_organizaciones_recursos_recurso
  ON public.tbl_usuarios_organizaciones_recursos (rec_id);

-- Conserva el comportamiento actual: cada pertenencia COBRADOR recibe una
-- copia de los permisos que hasta ahora heredaba del rol global.
INSERT INTO public.tbl_usuarios_organizaciones_recursos (urg_id, rec_id)
SELECT DISTINCT uo.id_urg, rr.rec_id
FROM public.tbl_usuarios_organizaciones uo
JOIN public.tbl_roles rol
  ON rol.id_rol = uo.rol_id
JOIN public.tbl_roles_recursos rr
  ON rr.rol_id = rol.id_rol
JOIN public.tbl_recursos recurso
  ON recurso.id_rec = rr.rec_id
WHERE uo.urg_activo
  AND rol.rol_tip::text = 'COBRADOR'
  AND recurso.rec_interface::text = 'WEB'
  AND recurso.nom IN (
    'CREAR_CAJA_MENOR',
    'REGISTRAR_FLUJO_CAJA',
    'CREAR_CREDITOS',
    'REFINANCIAR_CREDITOS',
    'MODIFICAR_CREDITOS',
    'ELIMINAR_CREDITOS',
    'MODIFICAR_CLIENTES',
    'ELIMINAR_CLIENTES',
    'AGREGAR_CUOTA',
    'MODIFICAR_MOVIMIENTOS'
  )
ON CONFLICT (urg_id, rec_id) DO NOTHING;
