import 'package:sqflite_sqlcipher/sqflite.dart';

/// The branch a non-Owner account is granted access to when nothing more
/// specific was chosen: the first ACTIVE branch by `sort_order`, then
/// name. Falls back to the first branch of any kind if every branch is
/// currently switched off (access to an inactive branch does nothing
/// until it is reactivated, but it keeps the account's intended branch
/// instead of leaving it with none). Null only if there are no branches
/// at all.
///
/// One function, used from two places that cannot share a database
/// handle: AppDatabase's v13 migration/seed (which runs while the DB is
/// still being opened, so it only has the raw [Database] it was handed)
/// and UserManagementRepository.createUser (which goes through
/// AppDatabase.instance). Keeping the rule here means "what is the
/// default branch" has exactly one definition.
Future<String?> pickDefaultBranchId(Database db) async {
  final active = await db.query(
    'branches',
    columns: ['id'],
    where: 'is_active = 1',
    orderBy: 'sort_order ASC, name ASC',
    limit: 1,
  );
  if (active.isNotEmpty) return active.first['id'] as String;

  final any = await db.query(
    'branches',
    columns: ['id'],
    orderBy: 'sort_order ASC, name ASC',
    limit: 1,
  );
  return any.isEmpty ? null : any.first['id'] as String;
}
