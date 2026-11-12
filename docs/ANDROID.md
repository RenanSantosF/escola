# Executar e testar no Android

## Pré-requisitos (uma vez)

1. **Godot 4.7.2** + **Export Templates 4.7.2** (Editor → *Gerenciar modelos de exportação* → *Baixar*).
2. **Android SDK** (via Android Studio ou `commandlinetools`) com:
   `platform-tools`, `build-tools;34.0.0`, `platforms;android-34`.
3. **JDK 17**.
4. No Godot: *Editor → Configurações do editor → Exportar → Android*:
   * `Java SDK Path` → pasta do JDK 17
   * `Android SDK Path` → pasta do SDK
5. Keystore de debug: o Godot cria automaticamente em `~/.local/share/godot/keystores/debug.keystore`
   (ou gere com `keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore debug.keystore -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999`).

## Rodar direto no celular (mais rápido)

1. Ative *Opções do desenvolvedor* → *Depuração USB* no aparelho e conecte via USB.
2. No editor, clique no ícone do Android (canto superior direito) → **Remote Deploy**.

## Gerar APK

O preset **Android** já está em `export_presets.cfg` (paisagem, arm64-v8a + armeabi-v7a,
tela imersiva, pacote `com.recreio.minhavidanaescola`, pastas `tests/`, `tools/` e `docs/`
excluídas).

```bash
godot --headless --export-debug "Android" build/recreio.apk
adb install -r build/recreio.apk
```

Para a Google Play use `--export-release` com um keystore de release e, de preferência,
`gradle_build/export_format=1` (AAB).

## O que verificar no aparelho

* A tela abre em paisagem e respeita o notch (os botões usam a *safe area*).
* Qualidade inicial: aparelhos com ≤ 4 núcleos ou sem Vulkan começam em **Baixa**.
  Ative *Mostrar FPS* em Configurações para medir.
* Botão **voltar** do Android abre/fecha a pausa; minimizar o app salva o progresso.
* Teste com vários dedos: andar + girar câmera + apertar pulo ao mesmo tempo.

## Renderer

O projeto usa o renderer **Mobile** (Vulkan) com `rendering_device/fallback_to_opengl3=true`:
aparelhos sem Vulkan adequado caem automaticamente para OpenGL ES 3 (Compatibility).
Todos os shaders e efeitos foram testados no renderer de compatibilidade.

## Limitação do ambiente de desenvolvimento

O APK não foi gerado no ambiente de nuvem usado nesta etapa (sem export templates nem
Android SDK). O jogo foi validado em Linux com o renderer de compatibilidade (o mesmo
usado como fallback no Android), com 55 testes automatizados e capturas de tela.
