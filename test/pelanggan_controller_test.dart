import 'package:flutter_test/flutter_test.dart';
import 'package:mamam_kasir/features/pelanggan/application/pelanggan_provider.dart';
import 'package:mamam_kasir/features/pelanggan/domain/pelanggan_models.dart';

void main() {
  late PelangganController controller;

  setUp(() {
    // Fresh controller seeded with the 7 dummy customers each test, so
    // tests can't leak state into each other.
    controller = PelangganController();
  });

  tearDown(() => controller.dispose());

  int count() => controller.state.customers.length;

  group('state awal', () {
    test('7 pelanggan dummy, tab Loyal, tanpa search, periode Semua Waktu', () {
      expect(count(), 7);
      expect(controller.state.sort, PelangganSort.loyal);
      expect(controller.state.searchQuery, '');
      expect(controller.state.period, PelangganPeriod.semuaWaktu);
    });

    test('tab Loyal tanpa search menampilkan footer aktif 4/7', () {
      expect(controller.state.showActiveFooter, isTrue);
      expect(controller.state.activeCount, 4);
      expect(controller.state.totalCount, 7);
    });

    test('visible di Loyal = 5 teratas', () {
      expect(controller.state.visible.length, 5);
    });
  });

  group('footer "Pelanggan aktif X/Y"', () {
    test('hilang saat pindah ke tab Semua', () {
      controller.setSort(PelangganSort.semua);
      expect(controller.state.showActiveFooter, isFalse);
    });

    test('hilang saat sedang search di tab Loyal', () {
      controller.setSearchQuery('joko');
      expect(controller.state.showActiveFooter, isFalse);
    });

    test('muncul lagi setelah search dibersihkan', () {
      controller.setSearchQuery('joko');
      controller.clearSearch();
      expect(controller.state.showActiveFooter, isTrue);
    });

    test('query hanya spasi tidak dianggap search', () {
      controller.setSearchQuery('   ');
      expect(controller.state.isSearching, isFalse);
      expect(controller.state.showActiveFooter, isTrue);
    });

    test('Y = SELURUH pelanggan walau list dipotong top-5', () {
      expect(controller.state.visible.length, 5);
      expect(controller.state.totalCount, 7);
    });
  });

  group('search lintas tab', () {
    test('search di tab Loyal menemukan Joko (di luar top 5)', () {
      controller.setSearchQuery('joko');
      expect(controller.state.visible.map((c) => c.name), ['Joko Prasetyo']);
    });

    test('pindah tab mempertahankan query search', () {
      controller.setSearchQuery('siti');
      controller.setSort(PelangganSort.semua);
      expect(controller.state.searchQuery, 'siti');
      expect(controller.state.visible.map((c) => c.name), ['Siti Aminah']);
    });
  });

  group('save — tambah pelanggan', () {
    test('berhasil: nama saja (HP dan alamat opsional)', () {
      final r = controller.save(editingId: null, name: 'Rina', phones: [''], address: '');
      expect(r, isA<PelangganSaved>());
      expect(count(), 8);
      final saved = (r as PelangganSaved).customer;
      expect(saved.name, 'Rina');
      expect(saved.phones, isEmpty);
      expect(saved.omzet, 0);
      expect(saved.lastOrderDaysAgo, isNull);
      expect(saved.history, isEmpty);
    });

    test('nama di-trim', () {
      final r = controller.save(editingId: null, name: '  Rina  ', phones: [], address: '');
      expect((r as PelangganSaved).customer.name, 'Rina');
    });

    test('nama kosong ditolak, data tidak berubah', () {
      final r = controller.save(editingId: null, name: '', phones: [], address: '');
      expect(r, isA<PelangganNameRequired>());
      expect(count(), 7);
    });

    test('nama hanya spasi ditolak', () {
      final r = controller.save(editingId: null, name: '   ', phones: [], address: '');
      expect(r, isA<PelangganNameRequired>());
      expect(count(), 7);
    });

    test('lebih dari satu nomor HP disimpan semua, tanpa nomor utama', () {
      final r = controller.save(
        editingId: null,
        name: 'Rina',
        phones: ['0899 0000 1111', '0898 2222 3333'],
        address: '',
      );
      final saved = (r as PelangganSaved).customer;
      expect(saved.phones, ['0899 0000 1111', '0898 2222 3333']);
    });

    test('nomor kosong di antara nomor valid dibuang', () {
      final r = controller.save(
        editingId: null,
        name: 'Rina',
        phones: ['0899 0000 1111', '', '  '],
        address: '',
      );
      expect((r as PelangganSaved).customer.phones, ['0899 0000 1111']);
    });

    test('id pelanggan baru unik dan bertambah', () {
      final a = (controller.save(editingId: null, name: 'A', phones: [], address: '') as PelangganSaved).customer;
      final b = (controller.save(editingId: null, name: 'B', phones: [], address: '') as PelangganSaved).customer;
      expect(a.id, isNot(b.id));
      expect(controller.state.customers.map((c) => c.id).toSet().length, count());
    });
  });

  group('save — nomor duplikat (satu nomor = satu pelanggan)', () {
    test('ditolak dan pemilik existing dikembalikan', () {
      final r = controller.save(
        editingId: null,
        name: 'Rina',
        phones: ['0812 3456 7890'],
        address: '',
      );
      expect(r, isA<PelangganPhoneTaken>());
      final clash = (r as PelangganPhoneTaken).clash;
      expect(clash.owner.name, 'Budi Santoso');
      expect(clash.phone, '0812 3456 7890');
      expect(count(), 7, reason: 'penolakan tidak boleh menambah pelanggan');
    });

    test('ditolak walau format spasi berbeda', () {
      final r = controller.save(editingId: null, name: 'Rina', phones: ['08123456 7890'], address: '');
      expect(r, isA<PelangganPhoneTaken>());
    });

    test('nama kosong dicek SEBELUM nomor duplikat', () {
      final r = controller.save(editingId: null, name: '', phones: ['0812 3456 7890'], address: '');
      expect(r, isA<PelangganNameRequired>());
    });
  });

  group('save — edit pelanggan', () {
    test('berhasil mengubah nama, nomor, alamat; jumlah tetap', () {
      final r = controller.save(
        editingId: 1,
        name: 'Budi S.',
        phones: ['0899 1111 2222'],
        address: 'Jl. Baru 1',
      );
      expect(r, isA<PelangganSaved>());
      expect(count(), 7);
      final updated = controller.state.byId(1)!;
      expect(updated.name, 'Budi S.');
      expect(updated.phones, ['0899 1111 2222']);
      expect(updated.address, 'Jl. Baru 1');
    });

    test('edit tidak mengubah omzet, transaksi, dan riwayat', () {
      final before = controller.state.byId(1)!;
      controller.save(editingId: 1, name: 'Budi S.', phones: [], address: '');
      final after = controller.state.byId(1)!;
      expect(after.omzet, before.omzet);
      expect(after.trxCount, before.trxCount);
      expect(after.history.length, before.history.length);
      expect(after.lastPurchase, same(before.lastPurchase));
    });

    test('mempertahankan nomor sendiri TIDAK dianggap duplikat', () {
      final r = controller.save(
        editingId: 1,
        name: 'Budi Santoso',
        phones: ['0812 3456 7890'],
        address: '',
      );
      expect(r, isA<PelangganSaved>());
    });

    test('mengambil nomor pelanggan lain ditolak', () {
      final r = controller.save(editingId: 1, name: 'Budi', phones: ['0856 1122 3344'], address: '');
      expect(r, isA<PelangganPhoneTaken>());
      expect((r as PelangganPhoneTaken).clash.owner.name, 'Siti Aminah');
      expect(controller.state.byId(1)!.phones, ['0812 3456 7890'], reason: 'data lama tidak berubah');
    });

    test('boleh menghapus semua nomor (HP opsional)', () {
      final r = controller.save(editingId: 1, name: 'Budi', phones: [], address: '');
      expect(r, isA<PelangganSaved>());
      expect(controller.state.byId(1)!.phones, isEmpty);
    });

    test('nama kosong ditolak, data lama utuh', () {
      final r = controller.save(editingId: 1, name: '', phones: [], address: '');
      expect(r, isA<PelangganNameRequired>());
      expect(controller.state.byId(1)!.name, 'Budi Santoso');
    });

    test('edit pelanggan yang sudah terhapus -> PelangganNotFound (bukan "nama wajib")', () {
      controller.delete(1);
      final r = controller.save(editingId: 1, name: 'Budi', phones: [], address: '');
      expect(r, isA<PelangganNotFound>());
      expect(r, isNot(isA<PelangganNameRequired>()));
      expect(controller.state.byId(1), isNull, reason: 'tidak boleh menghidupkan lagi pelanggan yang terhapus');
    });
  });

  group('delete', () {
    test('menghapus pelanggan yang dipilih saja', () {
      controller.delete(3);
      expect(count(), 6);
      expect(controller.state.byId(3), isNull);
      expect(controller.state.byId(1), isNotNull);
    });

    test('menghapus id yang tidak ada tidak error dan tidak mengubah apa pun', () {
      controller.delete(999);
      expect(count(), 7);
    });

    test('nomor pelanggan yang dihapus bebas dipakai lagi', () {
      controller.delete(1);
      final r = controller.save(editingId: null, name: 'Pengganti', phones: ['0812 3456 7890'], address: '');
      expect(r, isA<PelangganSaved>());
    });

    test('peringkat pelanggan lain naik setelah yang teratas dihapus', () {
      controller.delete(1); // Budi, omzet tertinggi
      expect(controller.state.visible.first.name, 'Siti Aminah');
    });
  });

  group('periode detail', () {
    test('setPeriod lalu resetPeriod kembali ke Semua Waktu', () {
      controller.setPeriod(PelangganPeriod.hariIni);
      expect(controller.state.period, PelangganPeriod.hariIni);
      controller.resetPeriod();
      expect(controller.state.period, PelangganPeriod.semuaWaktu);
    });

    test('label periode sesuai mockup', () {
      expect(PelangganPeriod.hariIni.label, 'Hari Ini');
      expect(PelangganPeriod.bulanIni.label, 'Bulan Ini');
      expect(PelangganPeriod.semuaWaktu.label, 'Semua Waktu');
    });
  });
}
