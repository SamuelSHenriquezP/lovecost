# Nido (LoveCost) 🕊️💰 — Shared Finances for Couples

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Backend-Firebase%20Firestore-FFCA28?logo=firebase)]()
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![Author](https://img.shields.io/badge/Studio-Inventus%20Tech-orange)]()

> **Nido** es una plataforma de finanzas compartidas y presupuesto colaborativo para parejas (+13,400 líneas de código). Permite llevar el registro diario de gastos comunes, crear bolsillos de ahorro para metas conjuntas, organizar la lista de compras del hogar y analizar ciclos mensuales con un diseño cálido, moderno y transparente.

---

## 🌟 Características Principales

* **Modo Dual: Pareja en la Nube o Modo Invitado Autónomo:**
  * **Modo Pareja (Nube):** Vinculación de dos usuarios mediante código compartido con sincronización en tiempo real vía Firebase Cloud Firestore.
  * **Modo Invitado (100% Offline):** Almacenamiento local estructurado (`LocalGuestStorage`) que permite probar y usar toda la aplicación sin necesidad de conexión ni registro.
* **Gestión Integral de Gastos y Presupuestos:**
  * Categorización visual de gastos (supermercado, alquiler, salidas, servicios, mascotas).
  * División porcentual o 50/50 de los aportes de cada integrante de la pareja.
  * Reacciones interactivas a los gastos ingresados.
* **Bolsillos de Ahorro para Metas Comunes (*Savings Pockets*):**
  * Creación de metas de ahorro (vacaciones, muebles, emergencias) con seguimiento de progreso porcentual.
* **Lista de Compras Colaborativa en Vivo:**
  * Lista de artículos de despensa con marcado inmediato al hacer la compra en el supermercado.
* **Ciclos de Presupuesto Personalizados:**
  * Configuración del día de inicio de ciclo salarial (ej. quincenal o mensual) para cálculos precisos.
* **Capa de Persistencia Defensiva:**
  * Parseo tipado seguro (`_parseListSafe`) para prevenir excepciones de tipo en runtime.
  * Eliminación de timeouts agresivos para permitir que el SDK de Firestore sincronice fluidamente en segundo plano.

---

## 🏗️ Arquitectura del Código

```
nido/lovecost/
├── lib/
│   ├── models/
│   │   ├── expense.dart             # Entidad de gasto, tipo, categoría y reacciones
│   │   ├── pocket.dart              # Bolsillos y metas de ahorro compartidas
│   │   ├── shopping_item.dart       # Ítems de la lista de compras del hogar
│   │   └── couple_profile.dart      # Perfil de la pareja y código de vinculación
│   ├── services/
│   │   ├── nido_repository.dart     # Abstracción que conmuta entre Firestore y modo local
│   │   ├── services.dart            # LocalGuestStorage tolerante a fallos y utilidades
│   │   └── notification_service.dart# Recordatorios de gastos y cierre de ciclo
│   ├── screens/
│   │   ├── home_screen.dart         # Dashboard de gastos y balance mensual
│   │   ├── expenses_screen.dart     # Formulario de registro y desglose por categorías
│   │   ├── pockets_screen.dart      # Pantalla de bolsillos de ahorro
│   │   └── shopping_list_screen.dart# Lista de compras interactiva
│   └── main.dart                    # Inicialización y proveedores de tema
```

---

## 🚀 Puesta en Marcha

1. **Instalar dependencias:**
   ```bash
   cd Nido/lovecost
   flutter pub get
   ```

2. **Configuración de Firebase:**
   Asegúrate de contar con tu archivo `google-services.json` en `android/app/` o compila directamente en modo Invitado para probar de forma local.

3. **Ejecutar:**
   ```bash
   flutter run
   ```

---

**Desarrollado por Inventus Tech Studio** • *Liderado por Samuel Henríquez*
