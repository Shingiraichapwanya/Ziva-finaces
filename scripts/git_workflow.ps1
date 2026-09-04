<#
.SYNOPSIS
  git_workflow.ps1 - Automated Git & GitHub Versioning Helper for Ziva Finance
.DESCRIPTION
  Enforces versioning discipline, manages main/dev/feature branches, and automates conventional commits.
#>

param(
    [Parameter(Position = 0)]
    [ValidateSet('status', 'commit', 'branch', 'merge-dev', 'sync', 'help')]
    [string]$Action = 'status',

    [Parameter(Position = 1)]
    [string]$Message = '',

    [Parameter(Position = 2)]
    [string]$BranchName = ''
)

$ErrorActionPreference = 'Stop'
$MinGitCmd = "C:\Users\shing\AppData\Local\Programs\MinGit\cmd\git.exe"

if (Test-Path $MinGitCmd) {
    $env:Path = "$([System.IO.Path]::GetDirectoryName($MinGitCmd));$env:Path"
}

function Invoke-Git {
    param([string]$Cmd)
    Write-Host ">> git $Cmd" -ForegroundColor Cyan
    Invoke-Expression "git $Cmd"
}

switch ($Action) {
    'status' {
        Write-Host "=== Git Status ===" -ForegroundColor Green
        Invoke-Git "status"
        Write-Host "`n=== Active Branches ===" -ForegroundColor Green
        Invoke-Git "branch -v"
    }

    'commit' {
        if (-not $Message) {
            Write-Error "Please specify a commit message. Example: .\scripts\git_workflow.ps1 commit 'feat(command-center): add dashboard wireframe'"
        }
        Invoke-Git "add ."
        Invoke-Git "commit -m `"$Message`""
        Invoke-Git "log --oneline -n 3"
    }

    'branch' {
        if (-not $BranchName) {
            Write-Error "Please specify a branch name. Example: .\scripts\git_workflow.ps1 branch 'feature/predictive-burn'"
        }
        Invoke-Git "checkout -b $BranchName"
    }

    'merge-dev' {
        $currentBranch = (git branch --show-current).Trim()
        if ($currentBranch -eq 'dev' -or $currentBranch -eq 'main') {
            Write-Warning "Already on branch $currentBranch. Checkout a feature branch first."
            return
        }
        Write-Host "Merging $currentBranch into dev..." -ForegroundColor Yellow
        Invoke-Git "checkout dev"
        Invoke-Git "merge $currentBranch --no-ff -m `"merge($currentBranch): integrate into dev`""
        Invoke-Git "checkout $currentBranch"
    }

    'sync' {
        $hasRemote = git remote
        if (-not $hasRemote) {
            Write-Warning "No git remote configured yet. To add a remote run: git remote add origin <repo-url>"
            return
        }
        Invoke-Git "push origin HEAD"
    }

    'help' {
        Write-Host "Ziva Finance Git Workflow Automation" -ForegroundColor Green
        Write-Host "Usage:"
        Write-Host "  .\scripts\git_workflow.ps1 status"
        Write-Host "  .\scripts\git_workflow.ps1 commit 'feat(scope): message'"
        Write-Host "  .\scripts\git_workflow.ps1 branch 'feature/name'"
        Write-Host "  .\scripts\git_workflow.ps1 merge-dev"
        Write-Host "  .\scripts\git_workflow.ps1 sync"
    }
}
