# Hugging Face Space — Expense AI Service

Space SDK: **Docker** | Port: **7860**

## Push nhanh (Windows)

```powershell
cd c:\Nam4
git clone https://huggingface.co/spaces/YOUR_USERNAME/expense-ai
cd expense-ai

Copy-Item c:\Nam4\Doantotnghiep2\deploy\huggingface\Dockerfile .
Copy-Item c:\Nam4\Doantotnghiep2\deploy\huggingface\.dockerignore .
Copy-Item c:\Nam4\Doantotnghiep2\deploy\huggingface\.gitattributes .
Copy-Item c:\Nam4\Doantotnghiep2\ai_service\requirements.txt .
xcopy /E /I /Y c:\Nam4\Doantotnghiep2\ai_service\app app
xcopy /E /I /Y c:\Nam4\Doantotnghiep2\ai_service\models models

git lfs install
git lfs track "*.pt"
git add .
git commit -m "Deploy AI"
git push
```

## Secret (Settings → Repository secrets)

| Name | Value |
|------|-------|
| `GEMINI_API_KEY` | API key từ Google AI Studio |

## Test

```
https://YOUR_USERNAME-expense-ai.hf.space/health
```

Hướng dẫn đầy đủ: [../aws-split/README.md](../aws-split/README.md)
