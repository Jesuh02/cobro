export type AuthenticatedUser = {
  usuarioId: string;
  usuario: string;
  roles: string[];
};

export type AuthUserResponse = {
  id: string;
  usuario: string;
  nombreCompleto: string;
  correo: string;
  roles: string[];
  esAdministrador: boolean;
};

export type AuthSessionResponse = {
  token: string;
  usuario: AuthUserResponse;
};
