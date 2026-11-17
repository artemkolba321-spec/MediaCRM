import 'package:flutter_test/flutter_test.dart';
import 'package:media_crm/data/models/platform_channel.dart';
import 'package:media_crm/data/models/financial_operation.dart';
import 'package:media_crm/data/models/partner.dart';
import 'package:media_crm/data/models/publication.dart';
import 'package:media_crm/data/models/task.dart';
import 'package:media_crm/data/models/contact.dart';
import 'package:media_crm/data/models/advertiser.dart';
import 'package:media_crm/data/models/funnel.dart';

void main() {
  group('PlatformChannel serialization', () {
    test('round-trip JSON', () {
      final original = PlatformChannel(
        id: 'ch-1',
        userId: 'user1',
        platform: PlatformType.youtube,
        name: 'My Channel',
        url: 'https://youtube.com/c/mychannel',
        description: 'Test channel',
        platformId: 'UC123456',
        status: ChannelStatus.connected,
        subscriberCount: 15000,
        autoSync: true,
        syncIntervalMinutes: 180,
        authMethod: AuthMethod.oauth,
        hasCredentials: true,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 15),
      );

      final json = original.toJson();
      final restored = PlatformChannel.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.userId, original.userId);
      expect(restored.platform, original.platform);
      expect(restored.name, original.name);
      expect(restored.url, original.url);
      expect(restored.description, original.description);
      expect(restored.platformId, original.platformId);
      expect(restored.status, original.status);
      expect(restored.subscriberCount, original.subscriberCount);
      expect(restored.autoSync, original.autoSync);
      expect(restored.syncIntervalMinutes, original.syncIntervalMinutes);
      expect(restored.authMethod, original.authMethod);
      expect(restored.hasCredentials, original.hasCredentials);
    });

    test('defaults for optional fields', () {
      final json = {
        'id': 'ch-1',
        'user_id': 'user1',
        'platform': 'telegram',
        'name': 'TG Channel',
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-01T00:00:00Z',
      };

      final channel = PlatformChannel.fromJson(json);

      expect(channel.url, isNull);
      expect(channel.description, isNull);
      expect(channel.platformId, isNull);
      expect(channel.status, ChannelStatus.disconnected);
      expect(channel.subscriberCount, 0);
      expect(channel.autoSync, true);
      expect(channel.authMethod, AuthMethod.none);
      expect(channel.hasCredentials, false);
    });
  });

  group('FinancialOperation serialization', () {
    test('round-trip JSON', () {
      final original = FinancialOperation(
        id: 'op-1',
        userId: 'user1',
        type: TransactionType.income,
        status: TransactionStatus.completed,
        amount: 5000,
        currency: 'RUB',
        exchangeRate: 1,
        category: TransactionCategory.adRevenue,
        description: 'Ad revenue from YouTube',
        counterparty: 'Google',
        date: DateTime(2024, 1, 15),
        createdAt: DateTime(2024, 1, 15),
        updatedAt: DateTime(2024, 1, 15),
      );

      final json = original.toJson();
      final restored = FinancialOperation.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.type, original.type);
      expect(restored.status, original.status);
      expect(restored.amount, original.amount);
      expect(restored.currency, original.currency);
      expect(restored.category, original.category);
      expect(restored.description, original.description);
      expect(restored.counterparty, original.counterparty);
      expect(restored.date, original.date);
    });

    test('baseAmount calculation', () {
      final op = FinancialOperation(
        id: 'op-1',
        userId: 'user1',
        type: TransactionType.income,
        amount: 100,
        currency: 'USD',
        exchangeRate: 90,
        baseAmount: 9000,
        date: DateTime(2024, 1, 1),
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      expect(op.baseAmount, 9000); // 100 * 90
    });

    test('signedBaseAmount for different types', () {
      final income = FinancialOperation(
        id: '1',
        userId: 'user1',
        type: TransactionType.income,
        amount: 1000,
        date: DateTime(2024, 1, 1),
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
      expect(income.signedBaseAmount, 1000);

      final expense = FinancialOperation(
        id: '2',
        userId: 'user1',
        type: TransactionType.expense,
        amount: 500,
        date: DateTime(2024, 1, 1),
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
      expect(expense.signedBaseAmount, -500);

      final transfer = FinancialOperation(
        id: '3',
        userId: 'user1',
        type: TransactionType.transfer,
        amount: 300,
        date: DateTime(2024, 1, 1),
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );
      expect(transfer.signedBaseAmount, 0);
    });
  });

  group('Partner serialization', () {
    test('round-trip JSON', () {
      final json = {
        'id': 'partner-1',
        'user_id': 'user1',
        'name': 'Partner Corp',
        'company': 'Partner Corp Ltd',
        'contact_person': 'John Doe',
        'email': 'john@partner.com',
        'phone': '+7 900 123 4567',
        'website': 'https://partner.com',
        'notes': 'Key partner',
        'status': 'active',
        'promo_code': 'PARTNER10',
        'referral_link': 'https://partner.com/ref/abc',
        'commission_rate': 15,
        'clicks': 500,
        'registrations': 50,
        'confirmed_sales': 10,
        'total_commission': 1500,
        'paid_commission': 1000,
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-15T00:00:00Z',
      };

      final partner = Partner.fromJson(json);

      expect(partner.name, 'Partner Corp');
      expect(partner.company, 'Partner Corp Ltd');
      expect(partner.promoCode, 'PARTNER10');
      expect(partner.commissionRate, 15);
      expect(partner.clicks, 500);
      expect(partner.confirmedSales, 10);
      expect(partner.totalCommission, 1500);
      expect(partner.paidCommission, 1000);
      expect(partner.outstandingCommission, 500);
    });
  });

  group('Publication serialization', () {
    test('round-trip JSON', () {
      final json = {
        'id': 'pub-1',
        'user_id': 'user1',
        'platform': 'youtube',
        'channel_id': 'ch-1',
        'platform_post_id': 'video123',
        'title': 'My Video',
        'content': 'Video description',
        'image_url': 'https://img.youtube.com/vi/video123/maxresdefault.jpg',
        'url': 'https://youtube.com/watch?v=video123',
        'type': 'video',
        'published_at': '2024-01-15T10:00:00Z',
        'created_at': '2024-01-15T10:00:00Z',
        'updated_at': '2024-01-15T10:00:00Z',
      };

      final pub = Publication.fromJson(json);

      expect(pub.id, 'pub-1');
      expect(pub.platform, PlatformType.youtube);
      expect(pub.title, 'My Video');
      expect(pub.type, PublicationType.video);
      expect(pub.externalKey, 'video123');
    });
  });

  group('Task serialization', () {
    test('round-trip JSON', () {
      final json = {
        'id': 'task-1',
        'user_id': 'user1',
        'title': 'Upload video',
        'description': 'Record and upload the new tutorial',
        'priority': 'high',
        'status': 'inProgress',
        'category': 'content',
        'due_date': '2024-02-01',
        'created_at': '2024-01-15T00:00:00Z',
        'updated_at': '2024-01-15T00:00:00Z',
      };

      final task = Task.fromJson(json);

      expect(task.title, 'Upload video');
      expect(task.priority, TaskPriority.high);
      expect(task.status, TaskStatus.inProgress);
      expect(task.category, 'content');
    });

    test('Task overdue check', () {
      final task = Task(
        id: 'task-1',
        userId: 'user1',
        title: 'Old task',
        status: TaskStatus.todo,
        dueDate: DateTime.now().subtract(const Duration(days: 5)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(task.isOverdue(), true);

      final futureTask = Task(
        id: 'task-2',
        userId: 'user1',
        title: 'Future task',
        status: TaskStatus.todo,
        dueDate: DateTime.now().add(const Duration(days: 5)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(futureTask.isOverdue(), false);
    });
  });

  group('Contact serialization', () {
    test('round-trip JSON', () {
      final json = {
        'id': 'contact-1',
        'user_id': 'user1',
        'name': 'John Doe',
        'email': 'john@example.com',
        'phone': '+7 900 123 4567',
        'company': 'Acme Corp',
        'type': 'advertiser',
        'source': 'youtube',
        'notes': 'Interested in ad placement',
        'tags': ['premium', 'tech'],
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-15T00:00:00Z',
      };

      final contact = Contact.fromJson(json);

      expect(contact.name, 'John Doe');
      expect(contact.type, ContactType.advertiser);
      expect(contact.source, ContactSource.youtube);
      expect(contact.tags, ['premium', 'tech']);
    });
  });

  group('Advertiser serialization', () {
    test('round-trip JSON', () {
      final json = {
        'id': 'adv-1',
        'user_id': 'user1',
        'company_name': 'Acme Corp',
        'contact_person': 'Jane Smith',
        'email': 'jane@acme.com',
        'status': 'active',
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-15T00:00:00Z',
      };

      final adv = Advertiser.fromJson(json);

      expect(adv.companyName, 'Acme Corp');
      expect(adv.status, AdvertiserStatus.active);
    });
  });

  group('TransactionCategory', () {
    test('isIncome correctly identifies income categories', () {
      expect(TransactionCategory.adRevenue.isIncome, true);
      expect(TransactionCategory.subscription.isIncome, true);
      expect(TransactionCategory.sponsorship.isIncome, true);
      expect(TransactionCategory.affiliate.isIncome, true);
      expect(TransactionCategory.productSale.isIncome, true);
      expect(TransactionCategory.hosting.isIncome, false);
      expect(TransactionCategory.equipment.isIncome, false);
      expect(TransactionCategory.marketing.isIncome, false);
      expect(TransactionCategory.salary.isIncome, false);
      expect(TransactionCategory.taxes.isIncome, false);
      expect(TransactionCategory.fees.isIncome, false);
      expect(TransactionCategory.other.isIncome, false);
    });
  });

  group('PlatformType', () {
    test('all platforms have labels', () {
      for (final platform in PlatformType.values) {
        expect(platform.label, isNotEmpty);
        expect(platform.shortLabel, isNotEmpty);
        expect(platform.apiNote, isNotEmpty);
      }
    });

    test('supportsAutomaticSync excludes Boosty', () {
      expect(PlatformType.youtube.supportsAutomaticSync, true);
      expect(PlatformType.telegram.supportsAutomaticSync, true);
      expect(PlatformType.boosty.supportsAutomaticSync, false);
      expect(PlatformType.vk.supportsAutomaticSync, true);
      expect(PlatformType.github.supportsAutomaticSync, true);
    });
  });
}
