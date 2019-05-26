/**
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 *
 * Version: $Id$
 */

#if defined _dbupdater_included
  #endinput
#endif
#define _dbupdater_included

/**
 * API version.
 *
 * abbccde
 * a.b.c d (alpha: 1, beta: 3, RC: 5, stable: 7, PL: 9) e
 */
#define __DBUPDATER_APIVERSION      1000070
#define __DBUPDATER_USERVERSION     "1.0.0 R"

// We're required in `ArrayList` and in `Database`.
#include <adt_array>
#include <dbi>

/**
 * DB Updater procedure prototype.
 *
 * @param   iInstalledVersion       Version id for installed version. If this first run, this value will be equal `-1`.
 * @param   iProcessableVersion     Current processable version id.
 * @param   hTxn                    Transaction instance. Here you should add your queries for updates.
 * @param   hDriver                 Database driver.
 * @param   data                    Any custom user data (passed via DBUpdater_Add()).
 */
typedef DBUpdater_Procedure = function void (int iInstalledVersion, int iProcessableVersion, Transaction hTxn, DBDriver hDriver, any data);

/**
 * DB Updater callback.
 * Fired after processing procedures.
 *
 * @param   iInstalledVersion       Version id for installed version. Can be `-1`, if database failed on first update and database is empty.
 * @param   hDB                     Database connection handle.
 * @param   szError                 Error text. Can be empty, if all ok.
 * @param   data                    Any custom user data (passed via DBUpdater_Run()).
 */
typedef DBUpdater_Finished = function void (int iInstalledVersion, Database hDB, const char[] szError, any data);

// Here we storage all user passed procedures for updates with database version.
static ArrayList    g_hDBUpdater_Procedures;
static bool         g_bIsRunning;
static char         g_szMigrationsTable[64];
static char         g_szPluginIdentifier[64];
static Database     g_hDB;
static bool         g_bUnsafe;

/**
 * Initializes the memory.
 */
stock void DBUpdater_Start()
{
    // Allocate memory for procedures.
    g_hDBUpdater_Procedures = new ArrayList(ByteCountToCells(4));

    // Set default migrations table name.
    DBUpdater_SetTableName("__sourcepawn_migrations");

    // Generate identifier for plugin and set.
    // By default, we use plugin filename as "identifier".
    char szPluginIdentifier[64];
    GetPluginFilename(null, szPluginIdentifier, sizeof(szPluginIdentifier));
    DBUpdater_SetPluginIdentifier(szPluginIdentifier);

    g_bUnsafe = false;
}

/**
 * Checks, called DBUpdater_Start() or not.
 * @return  bool
 */
stock bool DBUpdater_IsStarted()
{
    return (g_hDBUpdater_Procedures != null);
}

/**
 * Checks, called DBUpdater_Run() or not.
 * @return  bool
 */
stock bool DBUpdater_IsRunning()
{
    return g_bIsRunning;
}

static void DBUpdater_WeAreStarted(bool bExpect = true)
{
    if (DBUpdater_IsStarted() == bExpect)
    {
        return;
    }

    DBUpdater_ThrowError();
}

static void DBUpdater_WeAreRunning(bool bExpect = true)
{
    if (DBUpdater_IsRunning() == bExpect)
    {
        return;
    }

    DBUpdater_ThrowError();
}

static void DBUpdater_ThrowError(const char[] szError = "DBUpdater has unexpected state for performing this operation!")
{
    ThrowError("%s", szError);
}

/**
 * Changes the table name for storaging all runned migrations.
 * Run this only if you need storage all migrations related with your plugin in table with plugin prefix.
 *
 * @param   szTableName     Table name for using.
 */
stock void DBUpdater_SetTableName(const char[] szTableName)
{
    DBUpdater_WeAreStarted();
    DBUpdater_WeAreRunning(false);
    strcopy(g_szMigrationsTable, sizeof(g_szMigrationsTable), szTableName);
}

/**
 * Changes the plugin identifier.
 * We recommend set your own unique plugin identifier, like "Kruzya_DiscordCore".
 *
 * @param   szPluginIdentifier  Plugin idenfifier for using.
 */
stock void DBUpdater_SetPluginIdentifier(const char[] szPluginIdentifier)
{
    DBUpdater_WeAreStarted();
    DBUpdater_WeAreRunning(false);
    strcopy(g_szPluginIdentifier, sizeof(g_szPluginIdentifier), szPluginIdentifier);
}

/**
 * Marks update progress as "unsafe". Allows you get database handle in migrations,
 * if you don't saved him or started from database configuration (requested updater
 * connect manually).
 */
stock void DBUpdater_MarkAsUnsafe()
{
    DBUpdater_WeAreStarted();
    DBUpdater_WeAreRunning(false);
    g_bUnsafe = true;
}

/**
 * Add a migration in storage.
 *
 * @param   iVersion        Version identifier. We recommend use "abbccde" system. In
 *                          user readable, this convert into "a.b.c d (alpha: 1, beta:
 *                          3, RC: 5, stable: 7, PL: 9) e
 * @param   ptrProcedure    Pointer on function for migrating.
 * @param   data            Any custom data. Will be passed onto procedure.
 */
stock void DBUpdater_Add(int iVersion, DBUpdater_Procedure ptrProcedure, any data = 0)
{
    DBUpdater_WeAreStarted();
    if (iVersion < 0)
    {
        ThrowError("Version id can't be lower than 0!");
    }

    DataPack hPack = new DataPack();
    hPack.WriteCell(iVersion);
    hPack.WriteFunction(ptrProcedure);
    hPack.WriteCell(data);

    g_hDBUpdater_Procedures.Push(hPack);
}

/**
 * Runs the all required migrations from database handle.
 *
 * @param   hDB             Database handle.
 * @param   ptrFinished     Callback-procedure for calling after all migrations
 *                          will be runned.
 * @param   data            Any custom data. Will be passed onto procedure.
 */
stock void DBUpdater_Run(Database hDB, DBUpdater_Finished ptrFinished, any data = 0)
{
    DBUpdater_WeAreStarted();

    DataPack hPack = new DataPack();
    hPack.WriteCell(-1);
    hPack.WriteFunction(ptrFinished);
    hPack.WriteCell(data);

    char szQuery[512];
    char szBaseQuery[512];
    if (hDB.Driver == view_as<DBDriver>(SQL_GetDriver("sqlite")))
    {
        strcopy(szBaseQuery, sizeof(szBaseQuery),
            "CREATE TABLE IF NOT EXISTS `%s` ( \
                plugin_id   VARCHAR (64) NOT NULL, \
                version_id  INTEGER (13) NOT NULL, \
                migrated_at INTEGER (13) NOT NULL, \
                CONSTRAINT `%s_plugin_migration` PRIMARY KEY ( \
                    plugin_id ASC, \
                    version_id ASC \
                ) \
                ON CONFLICT ROLLBACK \
            );"
        );
    } else {
        strcopy(szBaseQuery, sizeof(szBaseQuery), 
            "CREATE TABLE IF NOT EXISTS `%s` ( \
                `plugin_id` VARCHAR(64) NOT NULL COLLATE 'utf8_unicode_ci', \
                `version_id` INT(13) UNSIGNED NOT NULL, \
                `migrated_at` INT(13) UNSIGNED NOT NULL, \
                UNIQUE INDEX `%s_plugin_migration` (`plugin_id`, `version_id`) \
            ) COLLATE='utf8_unicode_ci' ENGINE=InnoDB;"
        );
    }

    g_bIsRunning = true;
    hDB.Format(szQuery, sizeof(szQuery), szBaseQuery, g_szMigrationsTable, g_szMigrationsTable);
    hDB.Query(_DBUpdater_OnFinishCreateMigrationTable, szQuery, hPack, DBPrio_High);
}

/***********************
 * DATABASE CALLBACKS. *
 ***********************/
static void _DBUpdater_OnFinishCreateMigrationTable(Database hDB, DBResultSet hResults, const char[] szError, DataPack hPack)
{
    // First: check error.
    if (szError[0])
    {
        DBUpdater_Finish(hDB, hPack, szError);
        return;
    }

    // If all ok, find installed migration.
    char szQuery[256];
    hDB.Format(szQuery, sizeof(szQuery), "SELECT `version_id` FROM `%s` WHERE `plugin_id` = '%s' ORDER BY `version_id` DESC LIMIT 1;", g_szMigrationsTable, g_szPluginIdentifier);
    hDB.Query(_DBUpdater_LookupCurrentMigrationVersion, szQuery, hPack, DBPrio_High);
}

static void _DBUpdater_InsertMigration(Database hDB, DBResultSet hResults, const char[] szError, DataPack hPack)
{}

static void _DBUpdater_LookupCurrentMigrationVersion(Database hDB, DBResultSet hResults, const char[] szError, DataPack hPack)
{
    // First: check error.
    if (!hResults)
    {
        DBUpdater_Finish(hDB, hPack, szError);
        return;
    }

    // If all ok, we need run required migrations.
    // For performing this operation, we need lookup latest installed migration.
    int iInstalledVersion = -1;
    if (hResults.FetchRow())
    {
        iInstalledVersion = hResults.FetchInt(0);
    }

    // Update datapack.
    DBUpdater_UpdateInstalledVersion(hPack, iInstalledVersion);
    DBUpdater_RunMigrations(hDB, hPack);
}

static void _DBUpdater_OnFinishTxn(Database hDB, DataPack hTxnPack, int iNumQueries, DBResultSet[] hResults, any[] queryData)
{
    // run next migration.
    hTxnPack.Reset();
    DataPack hPack = hTxnPack.ReadCell();
    DataPack hUpdate = hTxnPack.ReadCell();
    CloseHandle(hTxnPack);

    hUpdate.Reset();
    int iInstalledVersion = hUpdate.ReadCell();

    DBUpdater_UpdateInstalledVersion(hPack, iInstalledVersion);
    DBUpdater_MarkMigrationAsInstalled(hDB, iInstalledVersion);
    DBUpdater_RunMigrations(hDB, hPack);
}

static void _DBUpdater_OnFailTxn(Database hDB, DataPack hTxnPack, int iNumQueries, const char[] szError, int iFailIndex, any[] queryData)
{
    // Finish.
    hTxnPack.Reset();
    DataPack hPack = hTxnPack.ReadCell();
    CloseHandle(hTxnPack);

    DBUpdater_Finish(hDB, hPack, szError);
}

/**********
 * RUNNER *
 **********/
static void DBUpdater_RunMigrations(Database hDB, DataPack hPack)
{
    hPack.Reset();

    // Read current version.
    int iInstalledVersion = hPack.ReadCell();

    // Try find version upper.
    int iMaxVersion = DBUpdater_GetHighestVersion();

    // Find next migration for run.
    int iMigrationsCount = g_hDBUpdater_Procedures.Length;
    DataPack hMigrationPack;
    int iMigrationVersion;

    int iRunVersion = iMaxVersion;

    for (int iVersion = iMigrationsCount - 1; iVersion != -1; iVersion--)
    {
        hMigrationPack = g_hDBUpdater_Procedures.Get(iVersion);
        hMigrationPack.Reset();

        iMigrationVersion = hMigrationPack.ReadCell();
        iRunVersion = (iInstalledVersion < iMigrationVersion && iMigrationVersion <= iRunVersion) ? iMigrationVersion : iRunVersion;
    }

    if (iInstalledVersion == iRunVersion)
    {
        // We're already installed on fresh version. Just run finish callback.
        DBUpdater_Finish(hDB, hPack);
        return;
    }

    DBUpdater_RunMigration(hDB, hPack, iRunVersion);
}

static void DBUpdater_RunMigration(Database hDB, DataPack hPack, int iInstallableVersion)
{
    hPack.Reset();
    int iInstalledVersion = hPack.ReadCell();

    DataPack hUpdate = DBUpdater_FindVersion(iInstallableVersion);
    if (hUpdate == null)
    {
        // Unknown update.
        // Finish?
        char szError[256];
        FormatEx(szError, sizeof(szError), "INTERNAL ERROR: Found undefined update package (%d)", iInstallableVersion);
        DBUpdater_Finish(hDB, hPack, szError);
    }

    DBUpdater_Procedure ptrProcedure = view_as<DBUpdater_Procedure>(hUpdate.ReadFunction());
    Transaction hTxn = new Transaction();

    g_hDB = hDB;
    Call_StartFunction(null, ptrProcedure);
    Call_PushCell(iInstalledVersion);
    Call_PushCell(iInstallableVersion);
    Call_PushCell(hTxn);
    Call_PushCell(hDB.Driver);
    Call_PushCell(hUpdate.ReadCell());
    Call_Finish();
    g_hDB = null;

    DataPack hTxnPack = new DataPack();
    hTxnPack.WriteCell(hPack);
    hTxnPack.WriteCell(hUpdate);

    hDB.Execute(hTxn, _DBUpdater_OnFinishTxn, _DBUpdater_OnFailTxn, hTxnPack, DBPrio_High);
}

static void DBUpdater_Finish(Database hDB, DataPack hPack, const char[] szError = "")
{
    hPack.Reset();
    int iInstalledVersion = hPack.ReadCell();
    DBUpdater_Finished ptrCallback = view_as<DBUpdater_Finished>(hPack.ReadFunction());
    any data = hPack.ReadCell();
    CloseHandle(hPack);

    DBUpdater_CleanMemory();

    Call_StartFunction(null, ptrCallback);
    Call_PushCell(iInstalledVersion);
    Call_PushCell(hDB);
    Call_PushString(szError);
    Call_PushCell(data);
    Call_Finish();
}

static void DBUpdater_MarkMigrationAsInstalled(Database hDB, int iVersion)
{
    char szQuery[256];
    hDB.Format(szQuery, sizeof(szQuery), "INSERT INTO `%s` (`plugin_id`, `version_id`, `migrated_at`) VALUES ('%s', %d, %d);", g_szMigrationsTable, g_szPluginIdentifier, iVersion, GetTime());
    hDB.Query(_DBUpdater_InsertMigration, szQuery, _, DBPrio_High);
}

/***********
 * HELPERS *
 ***********/
static void DBUpdater_UpdateInstalledVersion(DataPack &hPack, int iInstalledVersion)
{
    // BUG: on some SourceMod versions, rewriting values just appends values. We need recreate datapack.
    DataPack hOriginal = hPack;
    hPack = new DataPack();

    // Write current version and copy all from old datapack.
    hPack.WriteCell(iInstalledVersion);
    hOriginal.Reset(); hOriginal.ReadCell(); // Skip version.
    hPack.WriteFunction(view_as<DBUpdater_Finished>(hOriginal.ReadFunction()));
    hPack.WriteCell(hOriginal.ReadCell());

    // Delete old datapack.
    CloseHandle(hOriginal);
}

static int DBUpdater_GetHighestVersion()
{
    int iCount = g_hDBUpdater_Procedures.Length;
    DataPack hPack;
    int iMaxVersion = -1;
    int iPackedVersion = 0;

    for (int iVersion = iCount - 1; iVersion != -1; iVersion--)
    {
        hPack = g_hDBUpdater_Procedures.Get(iVersion);
        hPack.Reset();
        iPackedVersion = hPack.ReadCell();

#define MAX(%0,%1)      (%0 > %1) ? %0 : %1
        iMaxVersion = MAX(iMaxVersion, iPackedVersion);
#undef MAX
    }

    return iMaxVersion;
}

static DataPack DBUpdater_FindVersion(int iVersion)
{
    int iCount = g_hDBUpdater_Procedures.Length;
    DataPack hPack;

    for (int iLookVersion = iCount - 1; iLookVersion != -1; iLookVersion--)
    {
        hPack = g_hDBUpdater_Procedures.Get(iLookVersion);
        hPack.Reset();

        if (hPack.ReadCell() == iVersion)
        {
            return hPack;
        }
    }

    return null;
}

static void DBUpdater_CleanMemory()
{
    g_bIsRunning = false;
    g_bUnsafe = false;
    g_hDB = null;

    int iCount = g_hDBUpdater_Procedures.Length;
    for (int iVersion = iCount - 1; iVersion != -1; iVersion--)
    {
        CloseHandle(g_hDBUpdater_Procedures.Get(iVersion));
    }

    CloseHandle(g_hDBUpdater_Procedures);
    g_hDBUpdater_Procedures = null;
}

/**********
 * UNSAFE *
 **********/
stock Database DBUpdater_GetDatabase()
{
    if (g_bUnsafe)
    {
        return g_hDB;
    }

    ThrowError("You should mark your update progress as \"unsafe\" for having ability use this method!");
    return null;
}

/**************************
 * HELPER MACRO-FUNCTIONS *
 **************************/
#if !defined _dbupdater_withoutmacros
#define __DBUPDATER_MAKEMIGRATION(%0)   static void _DBUpdater_%0_Migration(int iInstalledVersion, int iProcessableVersion, Transaction hTxn, DBDriver hDriver, any data)
#define __DBUPDATER_MIGRATIONPTR(%0)    _DBUpdater_%0_Migration
#define __DBUPDATER_ADD(%0)             DBUpdater_Add(%0, __DBUPDATER_MIGRATIONPTR(%0))
#endif