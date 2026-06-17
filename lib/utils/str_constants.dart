/// Configuración de Plazos y Umbrales para Sistema Operativo de Tiempo Real (SOTR) Crítico
/// Basado en Tablas de Análisis de Tiempos Reales del Proyecto BioLock
class STRConfig {
  // Plazos Máximos de Terminación (Deadlines - Di) según Tabla 1
  // Aumentados para absorber la carga matemática del mapeo vectorial geométrico
  
  // T-DET: Inferencia MobileFaceNet y conversión NV21
  static const int DEADLINE_T_DET = 300; // Antes 100
  
  // T-VAL: Validación (Distancia Euclidiana e iteración SQLite)
  static const int DEADLINE_T_VAL = 200; // Antes 50
  
  // T-BTX: Transmisión Serial RFCOMM
  static const int DEADLINE_T_BTX = 20;
  
  // T-ALM: Alarma de Rechazo
  static const int DEADLINE_T_ALM = 500;

  // Umbrales de Hardware (Tabla 2)
  // P-01: Distancia Euclidiana Máxima para Reconocimiento
  static const double MIN_CONFIDENCE = 0.6;
  
  // P-02: Luz Mínima
  static const int MIN_LIGHT_LEVEL = 30;
  
  // P-03: Exclusión de Cerradura (Tiempo de Sección Crítica)
  static const int TIEMPO_APERTURA_MS = 4000;
  
  // P-04: Tiempo de Debounce
  static const int TIEMPO_DEBOUNCE_MS = 500;

  // Configuración de Logging STR
  static const bool ENABLE_STR_LOGGING = true;
  static const bool ABORT_ON_DEADLINE_MISS = true;
}