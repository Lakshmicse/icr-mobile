# Fills the LOCAL portal database with the designs' content, or takes it out again.
#
#   powershell -File tool\seed\run.ps1             # seed (idempotent)
#   powershell -File tool\seed\run.ps1 -Remove     # remove, in reverse order
#
# Needs the portal checked out beside this repo (..\irc-portal), its dependencies
# installed, and its backend/.env pointing at a database on localhost. Each script
# refuses to run against any other database. See tool\seed\README.md.
param([switch]$Remove)

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$backend = (Resolve-Path (Join-Path $here '..\..\..\irc-portal\backend')).Path
$env:NODE_PATH = (Resolve-Path (Join-Path $backend '..\node_modules')).Path -replace '\\', '/'

# The order matters when seeding: the mentors, then learning and jobs, then
# events and councils (which set the personas' council seats and Bharat's CPD hours), then the personas'
# photos, then the Home feed and Bharat's profile menu (which read all of that). learning-flows reads only the
# portal's own papers and the two personas, so it can sit anywhere after them; it follows the other Learning seeds.
# mentoring_offerings seeds nothing: it only sweeps what the mentor desk's live tests leave, so it must stay right
# after mentoring (the list is reversed on -Remove, and it has to run before mentoring.ts --remove).
$scripts = @('mentorship', 'mentoring', 'mentoring_offerings', 'marketplace', 'learning-jobs', 'career', 'learning-study', 'learning-flows', 'events-councils', 'chapters', 'library', 'persona', 'home', 'forums', 'inbox', 'account', 'rfq')
if ($Remove) { [array]::Reverse($scripts) }

Push-Location $backend   # the scripts resolve `uploads` from the backend folder
try {
  foreach ($name in $scripts) {
    Write-Host "== $name$(if ($Remove) { ' (remove)' })"
    $script = (Join-Path $here "$name.ts") -replace '\\', '/'
    $arguments = @('ts-node', '--transpile-only', $script)
    if ($Remove) { $arguments += '--remove' }
    & npx @arguments
    if ($LASTEXITCODE -ne 0) { throw "$name failed (exit $LASTEXITCODE)" }
  }
  Write-Host 'Done.'
}
finally { Pop-Location }
