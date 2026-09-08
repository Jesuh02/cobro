import { ExportacionesService } from './exportaciones.service';

describe('ExportacionesService', () => {
  it('throws DomainError if row count exceeds maximum allowed', () => {
    const service = new ExportacionesService({} as never);

    expect(() => service.asegurarTamanoExportacion(10_001)).toThrow(
      'La exportacion supera el maximo de 10000 filas; aplica filtros mas especificos',
    );
  });

  it('creates preview correctly with headers and formatted rows', () => {
    const service = new ExportacionesService({} as never);

    const preview = service.crearVistaPreviaExportacion(
      [
        { header: 'Cliente', key: 'cliente', width: 20 },
        { header: 'Saldo', key: 'saldo', width: 10 },
      ],
      [
        { cliente: 'Juan', saldo: 5000 },
        { cliente: 'Maria', saldo: 10000 },
      ],
    );

    expect(preview.columnas).toEqual(['Cliente', 'Saldo']);
    expect(preview.filas).toHaveLength(2);
    expect(preview.filas[0]).toEqual(['Juan', 5000]);
    expect(preview.filas[1]).toEqual(['Maria', 10000]);
  });

  it('generates excel workbook and uploads to R2', async () => {
    const subirExcel = jest.fn().mockResolvedValueOnce({
      archivo: 'test-2026.xlsx',
      key: 'exportaciones/cobros/2026/test-2026.xlsx',
      url: 'https://r2.example.com/test-2026.xlsx',
      urlExpiraEnSegundos: 300,
    });

    const service = new ExportacionesService({
      subirExcel,
    } as never);

    const result = await service.generarYSubirExcel({
      carpeta: 'cobros',
      nombreBase: 'reporte-cobros',
      hojaNombre: 'Cobros',
      columnas: [
        { header: 'ID', key: 'id', width: 10 },
        { header: 'Monto', key: 'monto', width: 15 },
      ],
      filas: [{ id: '1', monto: 1000 }],
      columnasMonetarias: ['monto'],
    });

    expect(subirExcel).toHaveBeenCalled();
    expect(result.archivo).toBe('test-2026.xlsx');
    expect(result.filas).toBe(1);
    expect(result.vistaPrevia.columnas).toEqual(['ID', 'Monto']);
  });
});
