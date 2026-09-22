/// PLACEHOLDER seed data for the Modul Karyawan (HRD) prototype.
///
/// GENERATED from the values in hrd-mockup.html (roles, employees,
/// attendance, payroll items, approval requests, opening balances) so no
/// value was retyped by hand. Everything is in-memory demo data anchored
/// to a FIXED reference date — the prototype's numbers only make sense
/// relative to 2026-09-11, not to the device clock. Replace with real
/// repositories when the HRD module is specified in the PRD.
library;

import 'hrd_models.dart';

/// Fixed "today" of the prototype data set (NOT DateTime.now()).
const String kHrdPlaceholderToday = '2026-09-11';

/// Period shown on Overview / Detail / Rekap Kinerja.
const String kHrdPlaceholderMonth = '2026-09';

/// ⚠️ DUMMY PINs for the placeholder staff flow only — never real
/// credentials. Real PIN storage must be hashed / in secure storage per
/// AGENTS.md security rules, and the PIN screen must never reveal the
/// correct PIN in any form.
const Map<String, String> kHrdPlaceholderStaffPins = {
  'EMP-1001': '1234',
  'EMP-1002': '1111',
  'EMP-1003': '2222',
  'EMP-1004': '3333',
  'EMP-1005': '4444',
};

const List<HrdRole> kHrdSeedRoles = [
  HrdRole(id: 'manajer', name: 'Manajer', locked: true),
  HrdRole(id: 'kasir', name: 'Kasir', locked: false),
  HrdRole(id: 'kurir', name: 'Kurir', locked: false),
];

const List<Employee> kHrdSeedEmployees = [
  Employee(
    id: 'EMP-1001',
    name: 'Andi Wijaya',
    phone: '0812-3456-7890',
    address: 'Jl. Merdeka No. 12, Samarinda',
    status: EmployeeStatus.aktif,
    role: 'Kasir',
    wagePerHour: 15000,
    bonusFullTime: 25000,
    overtimeRatePer30Min: 5000,
    startDate: '2026-01-12',
  ),
  Employee(
    id: 'EMP-1002',
    name: 'Budi Santoso',
    phone: '0813-2233-4455',
    address: 'Jl. Antasari No. 5, Samarinda',
    status: EmployeeStatus.aktif,
    role: 'Kurir',
    wagePerHour: 14000,
    bonusFullTime: 20000,
    overtimeRatePer30Min: 5000,
    startDate: '2025-11-03',
  ),
  Employee(
    id: 'EMP-1003',
    name: 'Sari Dewanti',
    phone: '0821-9988-7766',
    address: 'Jl. Pahlawan No. 20, Samarinda',
    status: EmployeeStatus.aktif,
    role: 'Manajer',
    wagePerHour: 20000,
    bonusFullTime: 30000,
    overtimeRatePer30Min: 6000,
    startDate: '2024-06-20',
  ),
  Employee(
    id: 'EMP-1004',
    name: 'Rian Pratama',
    phone: '0857-1122-3344',
    address: 'Jl. Gajah Mada No. 8, Samarinda',
    status: EmployeeStatus.freelance,
    role: 'Kasir',
    wagePerHour: 13000,
    bonusFullTime: 0,
    overtimeRatePer30Min: 5000,
    startDate: '2026-03-01',
  ),
  Employee(
    id: 'EMP-1005',
    name: 'Dewi Lestari',
    phone: '0898-7766-5544',
    address: 'Jl. Diponegoro No. 3, Samarinda',
    status: EmployeeStatus.cuti,
    role: 'Kasir',
    wagePerHour: 15000,
    bonusFullTime: 25000,
    overtimeRatePer30Min: 5000,
    startDate: '2025-08-15',
  ),
  Employee(
    id: 'EMP-1006',
    name: 'Fajar Nugroho',
    phone: '0812-4433-2211',
    address: 'Jl. Sudirman No. 15, Samarinda',
    status: EmployeeStatus.resign,
    resignDate: '2026-08-20',
    role: 'Kurir',
    wagePerHour: 14000,
    bonusFullTime: 20000,
    overtimeRatePer30Min: 5000,
    startDate: '2025-02-10',
  ),
];

const List<AttendanceLog> kHrdSeedAttendance = [
  AttendanceLog(id: 'a1', employeeId: 'EMP-1001', date: '2026-09-01', type: AttendanceLogType.masuk, time: '08:58'),
  AttendanceLog(id: 'a2', employeeId: 'EMP-1001', date: '2026-09-01', type: AttendanceLogType.pulang, time: '19:05'),
  AttendanceLog(id: 'a3', employeeId: 'EMP-1001', date: '2026-09-02', type: AttendanceLogType.masuk, time: '09:03'),
  AttendanceLog(id: 'a4', employeeId: 'EMP-1001', date: '2026-09-02', type: AttendanceLogType.pulang, time: '19:00'),
  AttendanceLog(id: 'a5', employeeId: 'EMP-1001', date: '2026-09-03', type: AttendanceLogType.masuk, time: '08:25'),
  AttendanceLog(id: 'a6', employeeId: 'EMP-1001', date: '2026-09-03', type: AttendanceLogType.pulang, time: '20:15'),
  AttendanceLog(id: 'a7', employeeId: 'EMP-1001', date: '2026-09-04', type: AttendanceLogType.masuk, time: '08:55'),
  AttendanceLog(id: 'a8', employeeId: 'EMP-1001', date: '2026-09-04', type: AttendanceLogType.bolong, time: '13:00'),
  AttendanceLog(id: 'a9', employeeId: 'EMP-1001', date: '2026-09-04', type: AttendanceLogType.masukLagi, time: '14:30'),
  AttendanceLog(id: 'a10', employeeId: 'EMP-1001', date: '2026-09-04', type: AttendanceLogType.pulang, time: '19:00'),
  AttendanceLog(id: 'a11', employeeId: 'EMP-1001', date: '2026-09-05', type: AttendanceLogType.masuk, time: '08:58'),
  AttendanceLog(id: 'a12', employeeId: 'EMP-1001', date: '2026-09-05', type: AttendanceLogType.pulang, time: '19:02'),
  AttendanceLog(id: 'a13', employeeId: 'EMP-1001', date: '2026-09-08', type: AttendanceLogType.masuk, time: '09:10'),
  AttendanceLog(id: 'a14', employeeId: 'EMP-1001', date: '2026-09-08', type: AttendanceLogType.pulang, time: '19:00'),
  AttendanceLog(id: 'a15', employeeId: 'EMP-1001', date: '2026-09-09', type: AttendanceLogType.masuk, time: '08:59'),
  AttendanceLog(id: 'a16', employeeId: 'EMP-1001', date: '2026-09-09', type: AttendanceLogType.pulang, time: '19:40'),
  AttendanceLog(id: 'a17', employeeId: 'EMP-1001', date: '2026-09-10', type: AttendanceLogType.masuk, time: '08:58'),
  AttendanceLog(id: 'a18', employeeId: 'EMP-1001', date: '2026-09-10', type: AttendanceLogType.pulang, time: '19:00'),
  AttendanceLog(id: 'a19', employeeId: 'EMP-1001', date: '2026-09-11', type: AttendanceLogType.masuk, time: '08:57'),
  AttendanceLog(id: 'a20', employeeId: 'EMP-1001', date: '2026-09-11', type: AttendanceLogType.pulang, time: '19:01'),
  AttendanceLog(id: 'b1', employeeId: 'EMP-1002', date: '2026-09-01', type: AttendanceLogType.masuk, time: '09:00'),
  AttendanceLog(id: 'b2', employeeId: 'EMP-1002', date: '2026-09-01', type: AttendanceLogType.pulang, time: '19:00'),
  AttendanceLog(id: 'b3', employeeId: 'EMP-1002', date: '2026-09-02', type: AttendanceLogType.masuk, time: '09:05'),
  AttendanceLog(id: 'b4', employeeId: 'EMP-1002', date: '2026-09-02', type: AttendanceLogType.pulang, time: '18:50'),
  AttendanceLog(id: 'b5', employeeId: 'EMP-1002', date: '2026-09-03', type: AttendanceLogType.libur),
  AttendanceLog(id: 'b6', employeeId: 'EMP-1002', date: '2026-09-04', type: AttendanceLogType.masuk, time: '09:00'),
  AttendanceLog(id: 'b7', employeeId: 'EMP-1002', date: '2026-09-04', type: AttendanceLogType.pulang, time: '19:30'),
  AttendanceLog(id: 'b8', employeeId: 'EMP-1002', date: '2026-09-05', type: AttendanceLogType.masuk, time: '09:02'),
  AttendanceLog(id: 'b9', employeeId: 'EMP-1002', date: '2026-09-05', type: AttendanceLogType.pulang, time: '19:00'),
  AttendanceLog(id: 'b10', employeeId: 'EMP-1002', date: '2026-09-08', type: AttendanceLogType.masuk, time: '08:58'),
  AttendanceLog(id: 'b11', employeeId: 'EMP-1002', date: '2026-09-08', type: AttendanceLogType.pulang, time: '19:00'),
  AttendanceLog(id: 'b12', employeeId: 'EMP-1002', date: '2026-09-09', type: AttendanceLogType.masuk, time: '09:00'),
  AttendanceLog(id: 'b13', employeeId: 'EMP-1002', date: '2026-09-09', type: AttendanceLogType.pulang, time: '19:00'),
  AttendanceLog(id: 'b14', employeeId: 'EMP-1002', date: '2026-09-10', type: AttendanceLogType.masuk, time: '09:00'),
  AttendanceLog(id: 'b15', employeeId: 'EMP-1002', date: '2026-09-10', type: AttendanceLogType.pulang, time: '19:00'),
  AttendanceLog(id: 'b16', employeeId: 'EMP-1002', date: '2026-09-11', type: AttendanceLogType.masuk, time: '09:00'),
  AttendanceLog(id: 'b17', employeeId: 'EMP-1002', date: '2026-09-11', type: AttendanceLogType.pulang, time: '19:00'),
  AttendanceLog(id: 'c1', employeeId: 'EMP-1003', date: '2026-09-01', type: AttendanceLogType.masuk, time: '08:50'),
  AttendanceLog(id: 'c2', employeeId: 'EMP-1003', date: '2026-09-01', type: AttendanceLogType.pulang, time: '19:15'),
  AttendanceLog(id: 'c3', employeeId: 'EMP-1003', date: '2026-09-02', type: AttendanceLogType.masuk, time: '08:45'),
  AttendanceLog(id: 'c4', employeeId: 'EMP-1003', date: '2026-09-02', type: AttendanceLogType.pulang, time: '19:20'),
  AttendanceLog(id: 'c5', employeeId: 'EMP-1003', date: '2026-09-03', type: AttendanceLogType.masuk, time: '08:55'),
  AttendanceLog(id: 'c6', employeeId: 'EMP-1003', date: '2026-09-03', type: AttendanceLogType.pulang, time: '19:00'),
  AttendanceLog(id: 'c7', employeeId: 'EMP-1003', date: '2026-09-04', type: AttendanceLogType.masuk, time: '08:59'),
  AttendanceLog(id: 'c8', employeeId: 'EMP-1003', date: '2026-09-04', type: AttendanceLogType.pulang, time: '19:00'),
  AttendanceLog(id: 'c9', employeeId: 'EMP-1003', date: '2026-09-05', type: AttendanceLogType.masuk, time: '08:50'),
  AttendanceLog(id: 'c10', employeeId: 'EMP-1003', date: '2026-09-05', type: AttendanceLogType.pulang, time: '19:30'),
  AttendanceLog(id: 'c11', employeeId: 'EMP-1003', date: '2026-09-11', type: AttendanceLogType.masuk, time: '08:58'),
  AttendanceLog(id: 'c12', employeeId: 'EMP-1003', date: '2026-09-11', type: AttendanceLogType.pulang, time: '19:00'),
  AttendanceLog(id: 'd1', employeeId: 'EMP-1004', date: '2026-09-02', type: AttendanceLogType.masuk, time: '10:00'),
  AttendanceLog(id: 'd2', employeeId: 'EMP-1004', date: '2026-09-02', type: AttendanceLogType.pulang, time: '18:00'),
  AttendanceLog(id: 'd3', employeeId: 'EMP-1004', date: '2026-09-05', type: AttendanceLogType.masuk, time: '10:00'),
  AttendanceLog(id: 'd4', employeeId: 'EMP-1004', date: '2026-09-05', type: AttendanceLogType.pulang, time: '18:00'),
  AttendanceLog(id: 'd5', employeeId: 'EMP-1004', date: '2026-09-09', type: AttendanceLogType.libur, auto: true),
];

const List<PayrollAddition> kHrdSeedAdditions = [
  PayrollAddition(
    id: 'add-1',
    employeeId: 'EMP-1001',
    label: 'THR',
    amount: 100000,
    date: '2026-09-05',
    category: 'Tambahan',
    source: PayrollSource.owner,
    approvedBy: 'Owner',
    approvedAt: '2026-09-05 10:00',
  ),
  PayrollAddition(
    id: 'add-2',
    employeeId: 'EMP-1002',
    label: 'Ongkir ekstra',
    amount: 50000,
    date: '2026-09-08',
    category: 'Tambahan',
    source: PayrollSource.owner,
    approvedBy: 'Owner',
    approvedAt: '2026-09-08 09:30',
  ),
];

const List<PayrollDeduction> kHrdSeedDeductions = [
  PayrollDeduction(
    id: 'ded-1',
    employeeId: 'EMP-1001',
    label: 'Kasbon',
    amount: 150000,
    date: '2026-09-03',
    category: 'Kasbon',
  ),
  PayrollDeduction(
    id: 'ded-2',
    employeeId: 'EMP-1003',
    label: 'Kasbon',
    amount: 200000,
    date: '2026-09-01',
    category: 'Kasbon',
  ),
];

const List<HrdApprovalRequest> kHrdSeedApprovals = [
  HrdApprovalRequest(
    id: 'req-1',
    type: HrdApprovalType.income,
    employeeId: 'EMP-1002',
    date: '2026-09-10',
    status: HrdApprovalStatus.menunggu,
    label: 'Ongkir antar pesanan', amount: 40000, note: 'Antar pesanan ke Jl. Pahlawan', 
  ),
];

/// Saldo Awal Bulan, keyed '<employeeId>|<yyyy-MM>'. Positive = employee
/// owes the company; negative = the company owes the employee.
const Map<String, int> kHrdSeedOpeningBalances = {
  'EMP-1001|2026-09': 0,
  'EMP-1003|2026-09': -50000,
};
