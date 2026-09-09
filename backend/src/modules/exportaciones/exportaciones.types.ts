export type ColumnaExportacion = {
  header: string;
  key: string;
  width: number;
};

export type FilaExportacion = Record<
  string,
  string | number | null | undefined
>;

export type ExportacionVistaPrevia = {
  columnas: string[];
  filas: Array<Array<string | number | null>>;
};

export type ExportacionExcel = {
  archivo: string;
  key: string;
  url: string;
  urlExpiraEnSegundos: number;
  filas: number;
  generadoEn: string;
  vistaPrevia: ExportacionVistaPrevia;
};
