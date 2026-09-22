import 'package:flutter_test/flutter_test.dart';
import 'package:mamam_kasir/features/pelanggan/domain/pelanggan_logic.dart';
import 'package:mamam_kasir/features/pelanggan/domain/pelanggan_models.dart';

Pelanggan _c(
  int id,
  String name, {
  List<String> phones = const [],
  int omzet = 0,
  int? days,
}) {
  return Pelanggan(
    id: id,
    name: name,
    phones: phones,
    address: '',
    lastPurchase: null,
    omzet: omzet,
    trxCount: 0,
    lastOrderDaysAgo: days,
    history: const [],
  );
}

List<String> _names(List<Pelanggan> l) => l.map((c) => c.name).toList();

void main() {
  // Same shape as the approved mockup's dummy data.
  final all = [
    _c(1, 'Budi Santoso', phones: ['0812 3456 7890'], omzet: 4850000, days: 1),
    _c(2, 'Siti Aminah', phones: ['0856 1122 3344'], omzet: 3210000, days: 3),
    _c(3, 'Andi Wijaya', phones: ['0821 9988 7766'], omzet: 2640000, days: 5),
    _c(4, 'Dewi Lestari', phones: ['0813 5566 7788'], omzet: 1920000, days: 7),
    _c(5, 'Rahmat Hidayat', omzet: 0),
    _c(6, 'Joko Prasetyo', phones: ['0857 4433 2211'], omzet: 385000, days: 67),
    _c(7, 'Maya Sari', phones: ['0878 6655 4433'], omzet: 760000, days: 45),
  ];

  group('sortedFiltered — tab Loyal', () {
    test('tanpa search: tepat 5 teratas, urut omzet menurun', () {
      final r = PelangganLogic.sortedFiltered(all, sort: PelangganSort.loyal, query: '');
      expect(r.length, 5);
      expect(r.map((c) => c.omzet).toList(), [4850000, 3210000, 2640000, 1920000, 760000]);
    });

    test('pelanggan omzet 0 dan omzet terkecil tidak masuk top 5', () {
      final r = PelangganLogic.sortedFiltered(all, sort: PelangganSort.loyal, query: '');
      expect(_names(r), isNot(contains('Rahmat Hidayat')));
      expect(_names(r), isNot(contains('Joko Prasetyo')));
    });

    test('search di tab Loyal menemukan pelanggan di luar top 5', () {
      final r = PelangganLogic.sortedFiltered(all, sort: PelangganSort.loyal, query: 'joko');
      expect(_names(r), ['Joko Prasetyo']);
    });

    test('search TIDAK dipotong 5 walau hasil lebih dari 5', () {
      // Huruf "a" ada di semua 7 nama.
      final r = PelangganLogic.sortedFiltered(all, sort: PelangganSort.loyal, query: 'a');
      expect(r.length, 7);
    });

    test('hasil search di Loyal tetap urut omzet menurun', () {
      final r = PelangganLogic.sortedFiltered(all, sort: PelangganSort.loyal, query: 'a');
      final omzets = r.map((c) => c.omzet).toList();
      expect(omzets, [...omzets]..sort((a, b) => b.compareTo(a)));
    });
  });

  group('sortedFiltered — tab Semua', () {
    test('semua pelanggan, urut A-Z', () {
      final r = PelangganLogic.sortedFiltered(all, sort: PelangganSort.semua, query: '');
      expect(r.length, 7);
      expect(_names(r), [
        'Andi Wijaya',
        'Budi Santoso',
        'Dewi Lestari',
        'Joko Prasetyo',
        'Maya Sari',
        'Rahmat Hidayat',
        'Siti Aminah',
      ]);
    });

    test('urut A-Z tidak peduli huruf besar/kecil', () {
      final mixed = [_c(1, 'budi'), _c(2, 'Andi'), _c(3, 'citra')];
      final r = PelangganLogic.sortedFiltered(mixed, sort: PelangganSort.semua, query: '');
      expect(_names(r), ['Andi', 'budi', 'citra']);
    });
  });

  group('sortedFiltered — search', () {
    test('by nama, case-insensitive', () {
      final r = PelangganLogic.sortedFiltered(all, sort: PelangganSort.semua, query: 'SITI');
      expect(_names(r), ['Siti Aminah']);
    });

    test('by nomor HP dengan spasi grup', () {
      final r = PelangganLogic.sortedFiltered(all, sort: PelangganSort.semua, query: '0812 3456');
      expect(_names(r), ['Budi Santoso']);
    });

    test('by nomor HP tanpa spasi (digit mentah)', () {
      final r = PelangganLogic.sortedFiltered(all, sort: PelangganSort.semua, query: '08123456');
      expect(_names(r), ['Budi Santoso']);
    });

    test('query hanya spasi dianggap kosong (tidak memfilter)', () {
      final r = PelangganLogic.sortedFiltered(all, sort: PelangganSort.semua, query: '   ');
      expect(r.length, 7);
    });

    test('tidak ada yang cocok -> list kosong', () {
      final r = PelangganLogic.sortedFiltered(all, sort: PelangganSort.semua, query: 'zzzz');
      expect(r, isEmpty);
    });

    test('tidak mengubah list asal (immutability)', () {
      final before = _names(all);
      PelangganLogic.sortedFiltered(all, sort: PelangganSort.semua, query: '');
      PelangganLogic.sortedFiltered(all, sort: PelangganSort.loyal, query: '');
      expect(_names(all), before);
    });
  });

  group('isActive / activeCount', () {
    test('order dalam 30 hari = aktif; tepat 30 aktif, 31 tidak', () {
      expect(PelangganLogic.isActive(_c(1, 'a', days: 1)), isTrue);
      expect(PelangganLogic.isActive(_c(1, 'a', days: 30)), isTrue);
      expect(PelangganLogic.isActive(_c(1, 'a', days: 31)), isFalse);
    });

    test('belum pernah order (null) tidak aktif', () {
      expect(PelangganLogic.isActive(_c(1, 'a', days: null)), isFalse);
    });

    test('activeCount dari data dummy = 4 (Budi, Siti, Andi, Dewi)', () {
      expect(PelangganLogic.activeCount(all), 4);
    });

    test('activeCount dihitung dari SEMUA data, bukan potongan top-5', () {
      // 6 pelanggan omzet besar tapi tidak aktif + 2 omzet kecil tapi aktif.
      // Top-5 omzet isinya semua yang tidak aktif: kalau dihitung dari
      // potongan top-5 hasilnya 0; dari seluruh data harus 2.
      final tricky = [
        for (var i = 1; i <= 6; i++) _c(i, 'Besar$i', omzet: 1000000 - i, days: 100),
        _c(10, 'KecilAktif1', omzet: 5000, days: 2),
        _c(11, 'KecilAktif2', omzet: 4000, days: 10),
      ];
      final top5 = PelangganLogic.sortedFiltered(tricky, sort: PelangganSort.loyal, query: '');
      expect(top5.where(PelangganLogic.isActive).length, 0);
      expect(PelangganLogic.activeCount(tricky), 2);
    });
  });

  group('rankOf', () {
    test('peringkat berdasarkan omzet dari SELURUH pelanggan', () {
      expect(PelangganLogic.rankOf(all, all[0]), 1); // Budi
      expect(PelangganLogic.rankOf(all, all[5]), 6); // Joko
      expect(PelangganLogic.rankOf(all, all[4]), 7); // Rahmat (omzet 0)
    });
  });

  group('findPhoneClash (satu nomor = satu pelanggan)', () {
    test('nomor milik pelanggan lain terdeteksi, pemilik dikembalikan', () {
      final clash = PelangganLogic.findPhoneClash(all, ['0812 3456 7890']);
      expect(clash, isNotNull);
      expect(clash!.owner.name, 'Budi Santoso');
    });

    test('terdeteksi walau format spasi beda (normalisasi digit)', () {
      final clash = PelangganLogic.findPhoneClash(all, ['08123456 7890']);
      expect(clash?.owner.id, 1);
    });

    test('edit diri sendiri tidak dianggap duplikat', () {
      expect(PelangganLogic.findPhoneClash(all, ['0812 3456 7890'], editingId: 1), isNull);
    });

    test('edit pelanggan lain tetap menabrak', () {
      final clash = PelangganLogic.findPhoneClash(all, ['0812 3456 7890'], editingId: 2);
      expect(clash?.owner.id, 1);
    });

    test('nomor baru yang bebas tidak menabrak', () {
      expect(PelangganLogic.findPhoneClash(all, ['0899 0000 1111']), isNull);
    });

    test('nomor kosong/spasi diabaikan (HP opsional)', () {
      expect(PelangganLogic.findPhoneClash(all, ['', '   ']), isNull);
    });

    test('salah satu dari beberapa nomor menabrak -> tetap terdeteksi', () {
      final clash = PelangganLogic.findPhoneClash(all, ['0899 0000 1111', '0856 1122 3344']);
      expect(clash?.owner.name, 'Siti Aminah');
      expect(clash?.phone, '0856 1122 3344');
    });
  });

  group('formatPhone (kelompok 4 digit, maks 13 digit)', () {
    test('081234567890 -> 0812 3456 7890', () {
      expect(PelangganLogic.formatPhone('081234567890'), '0812 3456 7890');
    });

    test('input sebagian', () {
      expect(PelangganLogic.formatPhone('0812'), '0812');
      expect(PelangganLogic.formatPhone('08123'), '0812 3');
      expect(PelangganLogic.formatPhone('08123456'), '0812 3456');
      expect(PelangganLogic.formatPhone('081234567'), '0812 3456 7');
    });

    test('membuang karakter non-digit', () {
      expect(PelangganLogic.formatPhone('0812-3456.7890'), '0812 3456 7890');
    });

    test('dibatasi 13 digit', () {
      final out = PelangganLogic.formatPhone('0812345678901234567');
      expect(PelangganLogic.digitsOnly(out).length, 13);
    });

    test('idempoten: memformat hasil format tidak mengubahnya', () {
      const once = '0812 3456 7890';
      expect(PelangganLogic.formatPhone(once), once);
    });

    test('kosong tetap kosong', () {
      expect(PelangganLogic.formatPhone(''), '');
    });
  });

  group('formatRp (persis mockup, dengan spasi)', () {
    test('ribuan dengan titik', () {
      expect(PelangganLogic.formatRp(4850000), 'Rp 4.850.000');
      expect(PelangganLogic.formatRp(68000), 'Rp 68.000');
      expect(PelangganLogic.formatRp(385000), 'Rp 385.000');
      expect(PelangganLogic.formatRp(1000), 'Rp 1.000');
    });

    test('kurang dari 1000 dan nol', () {
      expect(PelangganLogic.formatRp(999), 'Rp 999');
      expect(PelangganLogic.formatRp(0), 'Rp 0');
    });

    test('jutaan dan miliaran', () {
      expect(PelangganLogic.formatRp(1000000), 'Rp 1.000.000');
      expect(PelangganLogic.formatRp(1234567890), 'Rp 1.234.567.890');
    });

    test('negatif', () {
      expect(PelangganLogic.formatRp(-68000), '-Rp 68.000');
    });
  });
}
