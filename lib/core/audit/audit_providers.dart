import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audit_repository.dart';

final auditRepositoryProvider = Provider<AuditRepository>((ref) => AuditRepository());
