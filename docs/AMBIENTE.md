# Montar o ambiente (Windows, sem administrador)

Testado em 2026-10-24 em Windows 11, sem permissão de administrador, com um celular Android 13. Ocupa cerca de 4 GB.
Para só rodar as ferramentas de dados (`tools/`) basta o Node 20 ou mais novo; o resto é para o app.

| Peça | Versão testada |
|---|---|
| Git | qualquer recente |
| Node | 20 ou mais novo (testado com 24) |
| Java (JDK) | 17.0.10 (Microsoft Build of OpenJDK) |
| Flutter | 3.47.8, canal `stable` (Dart 3.13.7) |
| Android SDK | plataforma 36, build-tools 36.0.0, platform-tools 37.0.1 |

## 1. Java

```powershell
winget install --id Microsoft.OpenJDK.17 -e --scope user
```

Instala em `%LOCALAPPDATA%\Programs\Microsoft\jdk-17.0.10.7-hotspot`.

## 2. Flutter

```powershell
git clone https://github.com/flutter/flutter.git -b stable --depth 1 $env:USERPROFILE\dev\flutter
```

## 3. Android SDK (só as ferramentas de linha de comando, sem Android Studio)

1. Baixe `commandlinetools-win-*_latest.zip` em https://developer.android.com/studio#command-line-tools-only (testado: `11076708`, 147 MB).
2. Extraia de forma que exista `%LOCALAPPDATA%\Android\Sdk\cmdline-tools\latest\bin\sdkmanager.bat`
   (a pasta de dentro do zip se chama `cmdline-tools`; renomeie para `latest`).
3. No **Git Bash** (no PowerShell o "sim" automático não funcionou):

```bash
export JAVA_HOME="$LOCALAPPDATA/Programs/Microsoft/jdk-17.0.10.7-hotspot"
export PATH="$JAVA_HOME/bin:$PATH"
SDK="$LOCALAPPDATA/Android/Sdk"
yes | "$SDK/cmdline-tools/latest/bin/sdkmanager.bat" --sdk_root="$SDK" --licenses
"$SDK/cmdline-tools/latest/bin/sdkmanager.bat" --sdk_root="$SDK" "platform-tools" "platforms;android-36" "build-tools;36.0.0"
```

O primeiro comando aceita as licenças do Android SDK: leia-as antes se quiser.

## 4. Variáveis de ambiente (só do seu usuário)

```powershell
$jdk = "$env:LOCALAPPDATA\Programs\Microsoft\jdk-17.0.10.7-hotspot"
$sdk = "$env:LOCALAPPDATA\Android\Sdk"
[Environment]::SetEnvironmentVariable("JAVA_HOME", $jdk, "User")
[Environment]::SetEnvironmentVariable("ANDROID_HOME", $sdk, "User")
$p = [Environment]::GetEnvironmentVariable("Path", "User")
foreach ($a in "$env:USERPROFILE\dev\flutter\bin", "$jdk\bin", "$sdk\cmdline-tools\latest\bin", "$sdk\platform-tools") { if ($p -notlike "*$a*") { $p = "$p;$a" } }
[Environment]::SetEnvironmentVariable("Path", $p, "User")
```

Feche e abra o terminal. Depois:

```powershell
flutter config --android-sdk "$env:LOCALAPPDATA\Android\Sdk" --jdk-dir "$env:LOCALAPPDATA\Programs\Microsoft\jdk-17.0.10.7-hotspot"
flutter doctor -v
```

Esperado: `Flutter`, `Android toolchain`, `Chrome` e `Connected device` com ✓. O item **Visual Studio** aparece com ✗ e pode ser ignorado
(só serve para apps de Windows). A primeira execução baixa ferramentas do Flutter e leva alguns minutos.

## 5. Celular

1. Configurações → Sobre o telefone → toque 7 vezes em "Número da versão".
2. Opções do desenvolvedor → ligue **Depuração USB**.
3. **Xiaomi, Redmi e Poco (MIUI/HyperOS):** em geral é preciso ligar também **Instalar via USB** (mesmo menu). Sem isso a instalação pode falhar com
   `INSTALL_FAILED_USER_RESTRICTED`. Aceite o aviso que aparecer no celular na primeira instalação.
4. Conecte o cabo e aceite "Permitir depuração USB?".

```powershell
adb devices      # o aparelho deve aparecer como "device" (não "unauthorized")
flutter devices
```

## Armadilhas encontradas

- **Pasta com caminho longo ou com símbolos quebra o build.** Num teste, um projeto dentro de uma pasta temporária com caminho longo
  falhou em `impellerc failure: Could not write file`. Clone o projeto perto da raiz do disco ou do usuário
  (ex.: `C:\Users\você\www\busao-palmas`).
- **Build de teste:** um app Flutter vazio compilou com `flutter build apk --debug` em 138 s (a primeira vez baixa o Gradle e leva mais). O APK de debug tem 144 MB.
- No PowerShell, `yes | sdkmanager --licenses` não funciona; use o Git Bash.
- **Não verificado:** instalar e abrir no celular. Parou na etapa 5.3 por falta de "Instalar via USB" no celular de teste.
