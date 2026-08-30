export type AuthenticatedUser = {
  usuarioId: string;
  usuario: string;
  organizacionId: string | null;
  roles: string[];
  permisos: string[];
};

export type AuthUserResponse = {
  id: string;
  usuario: string;
  nombreCompleto: string;
  correo: string;
  roles: string[];
  organizacionId: string | null;
  esAdministrador: boolean;
  esSuperAdmin: boolean;
  activo: boolean;
  estado: {
    codigo: string;
    nombre: string;
  };
  permisos: string[];
};

export type AuthSessionResponse = {
  token: string;
  usuario: AuthUserResponse;
};
