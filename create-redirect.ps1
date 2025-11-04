# PowerShell script to extract tunnel URL, create redirect, and push to GitHub

$output = Get-Content 'tunnel-temp.txt' -ErrorAction SilentlyContinue -Raw

if ($output) {
    $match = [regex]::Match($output, 'https://[a-zA-Z0-9\-]+\.trycloudflare\.com')
    if ($match.Success) {
        $url = $match.Value
        Write-Host ""
        Write-Host "Tunnel URL: $url" -ForegroundColor Green
        Write-Host ""
        
        $timestamp = Get-Date -Format "yyyyMMddHHmmss"
        $html = @"
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate, max-age=0">
    <meta http-equiv="Pragma" content="no-cache">
    <meta http-equiv="Expires" content="0">
    <title>Librus Dashboard - Redirecting...</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .container {
            text-align: center;
            padding: 2rem;
        }
        .spinner {
            border: 4px solid rgba(255, 255, 255, 0.3);
            border-radius: 50%;
            border-top: 4px solid white;
            width: 40px;
            height: 40px;
            animation: spin 1s linear infinite;
            margin: 0 auto 1rem;
        }
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        a {
            color: white;
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="spinner"></div>
        <h1>Librus Dashboard</h1>
        <p>Redirecting...</p>
    </div>
    <script>
        // Force immediate redirect with multiple cache-busting methods
        (function() {
            var targetUrl = "$url";
            var timestamp = Date.now();
            var random = Math.random().toString(36).substring(7);
            
            // Multiple redirect methods to bypass all caches
            try {
                // Method 1: location.replace with timestamp
                window.location.replace(targetUrl + "?v=" + timestamp + "&r=" + random);
            } catch(e) {
                // Method 2: location.href as fallback
                window.location.href = targetUrl + "?v=" + timestamp + "&r=" + random;
            }
        })();
    </script>
    <noscript>
        <meta http-equiv="refresh" content="0; url=$url">
        <p>Redirecting to <a href="$url">application</a>...</p>
    </noscript>
</body>
</html>
"@
        
        Set-Content -Path 'redirect.html' -Value $html -Encoding UTF8
        Write-Host "Created redirect.html" -ForegroundColor Green
        
        # Git operations
        if (Test-Path ".git") {
            Write-Host ""
            Write-Host "Updating git repository..." -ForegroundColor Yellow
            
            # Configure git user if not set
            $gitUser = git config user.name 2>&1
            if ($LASTEXITCODE -ne 0 -or !$gitUser) {
                git config user.name "Davidonchik" 2>&1 | Out-Null
                git config user.email "davidonchik@users.noreply.github.com" 2>&1 | Out-Null
            }
            
            # Copy redirect.html to index.html for GitHub Pages
            Copy-Item -Path 'redirect.html' -Destination 'index.html' -Force
            Write-Host "Created index.html for GitHub Pages" -ForegroundColor Green
            
            # Create version file with timestamp to force GitHub Pages update
            $version = Get-Date -Format "yyyyMMddHHmmss"
            $versionContent = "Version: $version`nTunnel URL: $url`nUpdated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
            Set-Content -Path '.version' -Value $versionContent -Encoding UTF8
            Write-Host "Created .version file for cache busting" -ForegroundColor Green
            
            # Add and commit
            git add index.html redirect.html .version 2>&1 | Out-Null
            $commitMessage = "Update redirect to $url [v$version]"
            git commit -m $commitMessage 2>&1 | Out-Null
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Committed changes" -ForegroundColor Green
                
                # Check if remote exists
                $remote = git remote get-url origin 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Pushing to GitHub..." -ForegroundColor Yellow
                    git push origin main 2>&1 | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "Pushed to GitHub successfully!" -ForegroundColor Green
                    } else {
                        git push origin master 2>&1 | Out-Null
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "Pushed to GitHub successfully!" -ForegroundColor Green
                        } else {
                            Write-Host "Push failed. Check git credentials." -ForegroundColor Yellow
                        }
                    }
                } else {
                    Write-Host "No remote configured. Run setup-git.bat first." -ForegroundColor Yellow
                }
            } else {
                Write-Host "No changes to commit" -ForegroundColor Gray
            }
        } else {
            Write-Host ""
            Write-Host "Git repository not found. Run setup-git.bat to initialize." -ForegroundColor Yellow
        }
        
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Yellow
        Write-Host "  1. Upload redirect.html to GitHub Pages as index.html" -ForegroundColor Gray
        Write-Host "  2. Enable GitHub Pages in repository settings" -ForegroundColor Gray
        Write-Host "  3. Your static address: https://yourname.github.io/repo-name" -ForegroundColor Gray
    } else {
        Write-Host "URL not found yet. Check tunnel-temp.txt manually." -ForegroundColor Yellow
    }
} else {
    Write-Host "Could not read tunnel output." -ForegroundColor Yellow
}
