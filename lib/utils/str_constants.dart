/// Configuración de Plazos y Umbrales para Sistema Operativo de Tiempo Real (SOTR) Crítico
/// Basado en Tablas de Análisis de Tiempos Reales del Proyecto BioLock
class STRConfig {
  // Plazos Máximos de Terminación (Deadlines - Di) según Tabla 1
  // T-DET: Inferencia MobileFaceNet
  static const int DEADLINE_T_DET = 100;
  
  // T-VAL: Validación (Distancia Euclidiana)
  static const int DEADLINE_T_VAL = 50;
  
  // T-BTX: Transmisión Serial RFCOMM
  static const int DEADLINE_T_BTX = 10;
  
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
