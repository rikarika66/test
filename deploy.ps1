flutter build web --release --base-href "/test/"

Remove-Item docs\* -Recurse -Force
Copy-Item build\web\* docs\ -Recurse -Force

# ★ QR公開画像を毎回復元
New-Item -ItemType Directory -Path docs\qr_test -Force
Copy-Item .\qr_public\* .\docs\qr_test\ -Recurse -Force

git add .
git commit -m "Daily update"
git push
