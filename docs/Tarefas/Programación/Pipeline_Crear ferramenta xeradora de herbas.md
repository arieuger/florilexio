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
-  [ ] Fase 12
-  [ ] Fase 13
-  [ ] Fase 14
-  [ ] Fase 15
-  [ ] Fase 16
-  [ ] Fase 17
-  [ ] Fase 18
-  [ ] Fase 19

## Fase 1: Preparar o modelo de datos

```text
Crear PlantData como Resource base.
Engadir id único a PlantData.
Engadir nome principal a PlantData.
Engadir nomes alternativos a PlantData.
Engadir categoría da planta.
Engadir tipo de planta: herba, arbusto, árbore, outra.
Engadir descrición curta.
Engadir sprite de mundo.
Engadir sprite de hover.
Engadir icona de inventario.
Engadir icona de florilexio.
Crear cartafol res://data/plants/.
Crear 2-3 PlantData de proba.
```

## Fase 2: Separar datos de recolección

```text
Crear HarvestData como Resource.
Engadir tipo de minixogo a HarvestData.
Engadir variante de minixogo a HarvestData.
Engadir dificultade.
Engadir acertos necesarios.
Engadir fallos máximos.
Engadir velocidade do cursor.
Engadir custo de tempo por intento.
Engadir custo de tempo por fallo.
Engadir textura de zonas verdes.
Engadir obxectos necesarios.
Engadir obxectos facilitadores.
Conectar PlantData con HarvestData.
Crear HarvestData de proba para 2-3 plantas.
```

## Fase 3: Engadir coñecemento do florilexio

```text
Crear KnowledgeFragment como Resource.
Engadir tipo de fragmento: nome, visual, uso, perigo, lugar, memoria.
Engadir texto curto do fragmento.
Engadir texto longo do fragmento.
Engadir fonte de desbloqueo.
Engadir se é necesario para recolectar.
Conectar PlantData cunha lista de KnowledgeFragments.
Crear fragmento de nome para cada planta de proba.
Crear fragmento de identificación visual para cada planta de proba.
Crear fragmento extra opcional.
```

## Fase 4: Adaptar CollectablePlant

```text
Engadir export plant_data a CollectablePlant.
Cargar plant_id desde PlantData.
Cargar nome desde PlantData.
Cargar sprites desde PlantData.
Cargar marcas desde PlantData.
Cargar configuración de minixogo desde HarvestData.
Manter collection_id como dato de instancia.
Separar datos de especie e datos de instancia.
Facer que CollectablePlant consulte se a planta é recolectable.
Engadir fallback se falta PlantData.
```

## Fase 5: Cambiar punto de interacción por área

```text
Engadir InteractionArea a CollectablePlant.
Engadir CollisionShape2D ou CollisionPolygon2D a InteractionArea.
Manter InteractionTarget como punto de movemento.
Separar ClickArea de InteractionArea.
Facer que a xogadora poida interactuar se está dentro de InteractionArea.
Facer que a xogadora camiñe cara a InteractionTarget se está lonxe.
Engadir debug visual de InteractionArea.
Engadir debug visual de ClickArea.
```

## Fase 6: Crear plantilla de escena de planta

```text
Crear collectable_plant_base.tscn.
Engadir Sprite2D.
Engadir HoverSprite.
Engadir ClickArea.
Engadir InteractionArea.
Engadir InteractionTarget.
Engadir DebugGizmos.
Conectar script CollectablePlant.
Probar plantilla cunha planta real.
Crear escena herdada de proba.
```

## Fase 7: Crear plugin/dock mínimo

```text
Crear cartafol res://addons/florilexio_tools/.
Crear plugin.cfg.
Crear script principal do plugin.
Crear dock FlorilexioPlantsDock.
Engadir botón para activar/desactivar plugin.
Mostrar lista de PlantData existentes.
Permitir seleccionar PlantData.
Mostrar campos básicos de PlantData.
Mostrar preview simple de sprite.
```

## Fase 8: Crear xeración de escenas

```text
Engadir botón “Generate Plant Scene”.
Seleccionar PlantData actual.
Instanciar collectable_plant_base.tscn.
Asignar PlantData á escena.
Asignar sprites iniciais.
Crear ruta res://scenes/plants/.
Gardar escena como plant_id.tscn.
Evitar sobrescribir escena sen confirmación.
Abrir escena xerada despois de creala.
Crear escena de proba desde a ferramenta.
```

## Fase 9: Actualizar escenas existentes

```text
Engadir botón “Update Selected Plant Scene”.
Actualizar PlantData asignado.
Actualizar Sprite2D desde PlantData.
Actualizar HoverSprite desde PlantData.
Actualizar datos de minixogo.
Non pisar ClickArea manual.
Non pisar InteractionArea manual.
Non pisar InteractionTarget manual.
Engadir opción explícita “Rexenerar áreas”.
```

## Fase 10: Validación de planta

```text
Crear PlantValidator.
Validar que PlantData ten id.
Validar que PlantData ten nome.
Validar que PlantData ten sprite de mundo.
Validar que PlantData ten sprite de hover.
Validar que ten HarvestData se é recolectable.
Validar que HarvestData ten textura de zonas verdes.
Validar que ten fragmento de nome.
Validar que ten fragmento de identificación visual.
Validar que a escena ten ClickArea.
Validar que a escena ten InteractionArea.
Validar que a escena ten InteractionTarget.
Mostrar erros e avisos no dock.
```

## Fase 11: Validación global

```text
Engadir botón “Validate All Plants”.
Buscar todos os PlantData.
Buscar todas as escenas de plantas.
Detectar ids duplicados.
Detectar PlantData sen escena.
Detectar escenas sen PlantData.
Detectar plantas sen fragmentos obrigatorios.
Detectar HarvestData incompletos.
Mostrar resumo de erros.
```

## Fase 12: IDs de instancia

```text
Engadir collection_id visible en CollectablePlant.
Crear botón “Generate Missing Collection IDs”.
Xerar collection_id desde área + plant_id + índice.
Evitar duplicados na escena actual.
Mostrar aviso se collection_id está baleiro.
Mostrar aviso se collection_id está duplicado.
Non cambiar collection_id existente salvo confirmación.
```

## Fase 13: Integración co florilexio

```text
Crear FlorilexioManager mínimo.
Engadir estado observado.
Engadir estado nome desbloqueado.
Engadir estado identificación visual desbloqueada.
Engadir can_collect(plant_id).
Conectar CollectablePlant con FlorilexioManager.
Mostrar mensaxe se a planta non se pode recolectar.
Desbloquear observación ao interactuar cunha planta descoñecida.
Desbloquear recolección ao ter nome + visual.
```

## Fase 14: Preview de coñecemento

```text
Engadir pestana “Coñecemento” no dock.
Mostrar fragmentos da planta.
Mostrar se ten nome.
Mostrar se ten identificación visual.
Mostrar se sería recolectable.
Mostrar preview da ficha de florilexio.
Engadir botón debug “Desbloquear nome”.
Engadir botón debug “Desbloquear visual”.
Engadir botón debug “Reset coñecemento”.
```

## Fase 15: Integración con minixogo

```text
Crear HarvestMinigameManager.
Lanzar minixogo desde HarvestData.
Pasar textura de zonas verdes ao minixogo.
Pasar dificultade ao minixogo.
Pasar custos de tempo.
Pasar variante de minixogo.
Conectar éxito con inventario.
Conectar fallo con custo temporal.
Crear botón debug “Probar minixogo desta planta”.
```

## Fase 16: Melloras visuais do editor

```text
Debuxar gizmo de ClickArea.
Debuxar gizmo de InteractionArea.
Debuxar cruz de InteractionTarget.
Debuxar liña de pivote/Y-sort.
Engadir cores debug configurables.
Engadir botón para mostrar/ocultar gizmos.
Engadir preview do sprite normal.
Engadir preview do hover.
```

## Fase 17: Fluxo Aseprite/Assets

```text
Definir rutas estándar de sprites.
Definir rutas estándar de iconas.
Definir rutas estándar de hover sprites.
Engadir botón para buscar assets por plant_id.
Engadir aviso se falta algún PNG esperado.
Conectar PlantData con sprites exportados.
Probar fluxo Aseprite → PNG → PlantData → escena.
```

## Fase 18: Preparar para cachos extra

```text
Engadir bouquet_tags a PlantData.
Crear tags: bruxas, culinario, saúde, protección.
Mostrar tags no dock.
Validar tags baleiras en plantas tradicionais.
Preparar lectura de tags desde o calculador de cacho.
Non implementar receitas complexas aínda.
```

## Fase 19: Preparar obxectos

```text
Engadir required_equipment a HarvestData.
Engadir helpful_equipment a HarvestData.
Mostrar obxectos necesarios no dock.
Mostrar obxectos facilitadores no dock.
Validar que os obxectos existen.
Conectar luva como modificador simple.
Conectar tesoiras/vara como requisito simple.
```