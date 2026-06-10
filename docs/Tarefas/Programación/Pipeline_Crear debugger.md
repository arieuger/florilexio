---
tipo: programación
responsable: Roig
---
-  [ ] Fase 1
-  [ ] Fase 2
-  [ ] Fase 3
-  [ ] Fase 4
-  [ ] Fase 5
-  [ ] Fase 6
-  [ ] Fase 7
-  [ ] Fase 8
-  [ ] Fase 9
-  [ ] Fase 10
-  [ ] Fase 11
-  [ ] Post-florilexio

## ## Fase 1: Crear a base do panel

```text
Crear cartafol res://ui/debug/.
Crear cartafol res://scripts/debug/.
Crear escena debug_panel.tscn.
Crear script debug_panel.gd.
Facer que DebugPanel herde de CanvasLayer.
Engadir PanelContainer como contedor principal.
Engadir VBoxContainer para organizar seccións.
Ocultar DebugPanel por defecto.
Engadir apertura/peche con F1.
Limitar funcionamento a OS.is_debug_build().
Instanciar DebugPanel desde main.tscn.
```

## Fase 2: Crear estrutura visual mínima

```text
Crear sección “Tempo”.
Crear sección “Inventario”.
Crear sección “Florilexio”.
Crear sección “Minixogo”.
Crear sección “Mundo / fases”.
Crear sección “Reset”.
Engadir labels de título por sección.
Engadir separadores simples entre seccións.
Engadir botón para pechar o panel.
```

## Fase 3: Debug de tempo

```text
Engadir botón “+1 bloque”.
Engadir botón “+4 bloques”.
Conectar “+1 bloque” con GameState.add_consumed_time(1).
Conectar “+4 bloques” con GameState.add_consumed_time(4).
Crear GameState.debug_set_consumed_time().
Engadir botón “Ir á mañá”.
Engadir botón “Ir á tarde”.
Engadir botón “Ir ao solpor”.
Engadir botón “Ir á noite”.
Engadir botón “Ir ao final da xornada”.
Mostrar hora actual no panel.
Actualizar hora ao cambiar o tempo.
```

## Fase 4: Debug de inventario

```text
Engadir LineEdit para plant_id.
Engadir botón “Engadir planta”.
Conectar botón con InventoryManager.add_item().
Engadir botón “Baleirar inventario”.
Crear InventoryManager.debug_clear() se non existe.
Engadir botón “Abrir/pechar inventario”.
Mostrar resumo simple do inventario actual.
Actualizar resumo ao cambiar inventario.
```

## Fase 5: Debug de minixogo

```text
Engadir botón “Lanzar minixogo de corte”.
Crear función debug_launch_cutting_minigame().
Permitir lanzar minixogo con plant_id.
Usar configuración por defecto se non hai PlantData.
Permitir pechar minixogo sen afectar a partida.
Mostrar resultado do minixogo na consola.
Engadir botón “Probar minixogo fácil”.
Engadir botón “Probar minixogo difícil”.
```

## Fase 6: Debug de mundo e fases

```text
Engadir botón “Ir á mañá”.
Engadir botón “Ir á tarde”.
Engadir botón “Ir ao solpor”.
Engadir botón “Ir á noite”.
Engadir botón “Ir á fase ritual”.
Conectar fases con bloques de tempo representativos.
Engadir selector simple de área.
Engadir botón “Cambiar área”.
Engadir botón “Mover player a spawn”.
Engadir botón “Mostrar posición do player”.
```

## Fase 7: Reset e presets

```text
Engadir botón “Reset GameState”.
Engadir botón “Reset Inventario”.
Engadir botón “Reset Florilexio”.
Engadir botón “Reset todo debug”.
Crear GameState.debug_reset() se non existe.
Crear InventoryManager.debug_reset() se non existe.
Preparar reset de FlorilexioManager se existe.
Engadir preset “Inicio de partida”.
Engadir preset “Tarde con plantas”.
Engadir preset “Noite / final”.
```

## Fase 9: Seguridade e robustez

```text
Evitar erros se falta un manager.
Usar has_method antes de chamar funcións debug.
Engadir prints co prefixo [DebugPanel].
Evitar que o panel funcione en builds non-debug.
Evitar que o input do panel afecte á xogadora.
Pausar accións da xogadora mentres o panel está aberto se fai falta.
Pechar panel con Escape se está aberto.
```

## Fase 9: Melloras de usabilidade

```text
Engadir ScrollContainer ao panel.
Agrupar botóns por seccións despregables.
Mostrar estado actual de tempo.
Mostrar estado actual de inventario.
Mostrar plant_id seleccionado.
Engadir botón “Copiar estado debug”.
Engadir estilos mínimos para lexibilidade.
Engadir atallo visible: F1.
```

## Fase 10: Integración con novas ferramentas

```text
Conectar DebugPanel con FlorilexioManager cando exista.
Conectar DebugPanel con HarvestMinigameManager cando exista.
Conectar DebugPanel con EquipmentManager cando exista.
Engadir botóns para dar luva, cesto, tesoiras e vara.
Engadir botóns para probar estados de cacho.
Engadir botón para abrir pantalla final de xornada.
Engadir botón para probar magiómetro.
```

## Fase 11: Documentación mínima

```text
Crear nota DEBUG_PANEL.md.
Documentar como abrir o panel.
Documentar botóns dispoñibles.
Documentar funcións debug engadidas aos managers.
Documentar que non debe entrar en builds finais.
Engadir checklist para probar unha partida desde debug.
```

## Primeiro bloque mínimo recomendado

```text
Crear debug_panel.tscn.
Crear debug_panel.gd.
Abrir/pechar con F1.
Engadir +1 bloque.
Engadir +4 bloques.
Engadir plant_id LineEdit.
Engadir planta ao inventario.
Baleirar inventario.
Reset GameState.
Reset inventario.
```


## Post-florilexo: Debug de florilexio

```text
Crear sección FlorilexioManager.
Detectar se existe FlorilexioManager.
Mostrar aviso se FlorilexioManager non existe.
Engadir botón “Marcar observada”.
Engadir botón “Desbloquear nome”.
Engadir botón “Desbloquear identificación visual”.
Engadir botón “Marcar identificada”.
Engadir botón “Reset coñecemento”.
Reutilizar plant_id do LineEdit xeral.
Mostrar estado básico de coñecemento da planta.
```

