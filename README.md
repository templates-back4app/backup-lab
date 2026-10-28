# backup-lab

[![Deploy on Back4app](https://img.shields.io/badge/Deploy%20on-Back4app-1568B8?style=for-the-badge&logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCI+PHBhdGggZmlsbD0iI2ZmZiIgZD0iTTEyIDJMMiA3djEwbDEwIDUgMTAtNVY3eiIvPjwvc3ZnPg==)](https://www.back4app.com/signup?utm_source=github&utm_medium=repo&utm_campaign=backup-lab)

One dump, written to five places that differ in exactly one way: **what can reach
them**. Then five ways of losing the data, each against a freshly built stack.

A backup counts only if restoring it gives the rows back, so every surviving
archive is actually restored and its rows counted.

> **Read the article:** [Where to Keep Database Backups So the Command That Deletes Your Data Can't Reach Them](https://www.back4app.com/blog/database-backups-that-survive-deletion?utm_source=github&utm_medium=repo&utm_campaign=backup-lab)

## Run it

```
./run.sh
```

Needs Docker. Every run destroys and rebuilds everything it uses.

## What it found

| the backup lives | agent drops the db | container replaced | volumes removed | **agent runs `rm -rf`** | project folder deleted |
| --- | --- | --- | --- | --- | --- |
| 1. inside the container | ok | **gone** | **gone** | **gone** | ok |
| 2. in the data volume | ok | ok | **gone** | **gone** | ok |
| 3. another volume, same host | ok | ok | **gone** | **gone** | ok |
| 4. in the project folder | ok | ok | ok | **gone** | **gone** |
| 5. **where the database cannot reach** | ok | ok | ok | **ok** | ok |

Five hundred rows, restored and counted every time it says ok.

The fourth column is the one worth staring at. An agent with the access the
application already has deletes the database and **four of the five backups**. The
only survivor is the one it could not open — not because that copy is special, but
because the thing doing the damage had no route to it.

## The rule the matrix is really showing

A backup is only a backup with respect to a particular disaster. Location 4 — a
dump in the project folder — survives three of the five events and is the one most
people actually have. Location 5 survives all five, and the only reason is that
nothing which can destroy the data can also write there.

So the question to ask of your own backup is not "where is it?" It is: **can the
thing most likely to destroy my data also reach this copy?**

## The pieces

| file | what it does |
| --- | --- |
| `compose.yml` | the database and the five locations, differing only in what is mounted where |
| `lib.sh` | seed, back up to all five, and restore-check each one |
| `run.sh` | the five destruction events, each against a fresh stack |

## What to check in your own setup

1. Can the credentials your app uses also write to your backup store? If yes, an
   agent holding them can erase both.
2. Is your backup on the same machine, the same volume or the same account as the
   data it protects?
3. Have you ever restored one? A file that has never been restored is a file, not
   a backup.
4. Does your production data share an app, a database or a key with the thing you
   are testing against?
