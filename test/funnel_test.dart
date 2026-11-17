import 'package:flutter_test/flutter_test.dart';
import 'package:media_crm/data/models/funnel.dart';
import 'package:media_crm/core/utils/json_utils.dart';

void main() {
  group('Funnel', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': 'funnel-1',
        'user_id': 'user1',
        'name': 'Sales Funnel',
        'description': 'Main sales funnel',
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-01T00:00:00Z',
      };

      final funnel = Funnel.fromJson(json);

      expect(funnel.id, 'funnel-1');
      expect(funnel.userId, 'user1');
      expect(funnel.name, 'Sales Funnel');
      expect(funnel.description, 'Main sales funnel');
    });

    test('toJson serializes correctly', () {
      final funnel = Funnel(
        id: 'funnel-1',
        userId: 'user1',
        name: 'Test Funnel',
        description: 'Test',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      final json = funnel.toJson();

      expect(json['id'], 'funnel-1');
      expect(json['user_id'], 'user1');
      expect(json['name'], 'Test Funnel');
      expect(json['description'], 'Test');
    });

    test('copyWith creates updated copy', () {
      final funnel = Funnel(
        id: 'funnel-1',
        userId: 'user1',
        name: 'Old Name',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      final updated = funnel.copyWith(name: 'New Name');

      expect(updated.id, 'funnel-1');
      expect(updated.name, 'New Name');
      expect(updated.userId, 'user1');
    });
  });

  group('FunnelStage', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': 'stage-1',
        'funnel_id': 'funnel-1',
        'user_id': 'user1',
        'name': 'Lead',
        'order': 1,
        'color': '#8B7CFF',
      };

      final stage = FunnelStage.fromJson(json);

      expect(stage.id, 'stage-1');
      expect(stage.funnelId, 'funnel-1');
      expect(stage.name, 'Lead');
      expect(stage.order, 1);
      expect(stage.color, '#8B7CFF');
    });

    test('toJson serializes correctly', () {
      const stage = FunnelStage(
        id: 'stage-1',
        funnelId: 'funnel-1',
        userId: 'user1',
        name: 'Lead',
        order: 1,
        color: '#8B7CFF',
      );

      final json = stage.toJson();

      expect(json['id'], 'stage-1');
      expect(json['funnel_id'], 'funnel-1');
      expect(json['order'], 1);
    });
  });

  group('FunnelDeal', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': 'deal-1',
        'user_id': 'user1',
        'funnel_id': 'funnel-1',
        'stage_id': 'stage-1',
        'contact_name': 'John Doe',
        'contact_email': 'john@example.com',
        'value': 5000,
        'currency': 'RUB',
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-01T00:00:00Z',
      };

      final deal = FunnelDeal.fromJson(json);

      expect(deal.id, 'deal-1');
      expect(deal.contactName, 'John Doe');
      expect(deal.contactEmail, 'john@example.com');
      expect(deal.value, 5000);
      expect(deal.currency, 'RUB');
    });

    test('toJson serializes correctly', () {
      final deal = FunnelDeal(
        id: 'deal-1',
        userId: 'user1',
        funnelId: 'funnel-1',
        stageId: 'stage-1',
        contactName: 'John Doe',
        value: 5000,
        currency: 'RUB',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      final json = deal.toJson();

      expect(json['id'], 'deal-1');
      expect(json['contact_name'], 'John Doe');
      expect(json['value'], 5000);
    });

    test('copyWith updates stage and value', () {
      final deal = FunnelDeal(
        id: 'deal-1',
        userId: 'user1',
        funnelId: 'funnel-1',
        stageId: 'stage-1',
        contactName: 'John Doe',
        value: 5000,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
      );

      final updated = deal.copyWith(
        stageId: 'stage-2',
        value: 7500,
      );

      expect(updated.stageId, 'stage-2');
      expect(updated.value, 7500);
      expect(updated.id, 'deal-1');
      expect(updated.contactName, 'John Doe');
    });
  });

  group('calculateFunnelMetrics', () {
    test('calculates metrics for single stage', () {
      final stages = [
        FunnelStage(
          id: 'stage-1',
          funnelId: 'funnel-1',
          userId: 'user1',
          name: 'Lead',
          order: 1,
        ),
      ];
      final deals = [
        FunnelDeal(
          id: 'deal-1',
          userId: 'user1',
          funnelId: 'funnel-1',
          stageId: 'stage-1',
          contactName: 'John',
          value: 1000,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        ),
        FunnelDeal(
          id: 'deal-2',
          userId: 'user1',
          funnelId: 'funnel-1',
          stageId: 'stage-1',
          contactName: 'Jane',
          value: 2000,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 1),
        ),
      ];

      final metrics = calculateFunnelMetrics(stages, deals);

      expect(metrics.length, 1);
      expect(metrics[0].deals, 2);
      expect(metrics[0].value, 3000);
      expect(metrics[0].conversionFromPrevious, 100.0);
    });

    test('calculates conversion between stages', () {
      final stages = [
        FunnelStage(
          id: 'stage-1',
          funnelId: 'funnel-1',
          userId: 'user1',
          name: 'Lead',
          order: 1,
        ),
        FunnelStage(
          id: 'stage-2',
          funnelId: 'funnel-1',
          userId: 'user1',
          name: 'Qualified',
          order: 2,
        ),
        FunnelStage(
          id: 'stage-3',
          funnelId: 'funnel-1',
          userId: 'user1',
          name: 'Closed',
          order: 3,
        ),
      ];

      final deals = [
        // 10 leads
        for (var i = 0; i < 10; i++)
          FunnelDeal(
            id: 'lead-$i',
            userId: 'user1',
            funnelId: 'funnel-1',
            stageId: 'stage-1',
            contactName: 'Lead $i',
            value: 1000,
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
        // 5 qualified (50% conversion)
        for (var i = 0; i < 5; i++)
          FunnelDeal(
            id: 'qualified-$i',
            userId: 'user1',
            funnelId: 'funnel-1',
            stageId: 'stage-2',
            contactName: 'Qualified $i',
            value: 2000,
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
        // 2 closed (40% of qualified, 20% overall)
        for (var i = 0; i < 2; i++)
          FunnelDeal(
            id: 'closed-$i',
            userId: 'user1',
            funnelId: 'funnel-1',
            stageId: 'stage-3',
            contactName: 'Closed $i',
            value: 5000,
            createdAt: DateTime(2024, 1, 1),
            updatedAt: DateTime(2024, 1, 1),
          ),
      ];

      final metrics = calculateFunnelMetrics(stages, deals);

      expect(metrics.length, 3);
      expect(metrics[0].deals, 10);
      expect(metrics[0].conversionFromPrevious, 100.0);

      expect(metrics[1].deals, 5);
      expect(metrics[1].conversionFromPrevious, 50.0); // 5/10

      expect(metrics[2].deals, 2);
      expect(metrics[2].conversionFromPrevious, 40.0); // 2/5

      expect(metrics[2].lostFromPrevious, 3); // 5 - 2
    });

    test('sorts stages by order', () {
      final stages = [
        FunnelStage(
          id: 'stage-3',
          funnelId: 'funnel-1',
          userId: 'user1',
          name: 'Closed',
          order: 3,
        ),
        FunnelStage(
          id: 'stage-1',
          funnelId: 'funnel-1',
          userId: 'user1',
          name: 'Lead',
          order: 1,
        ),
        FunnelStage(
          id: 'stage-2',
          funnelId: 'funnel-1',
          userId: 'user1',
          name: 'Qualified',
          order: 2,
        ),
      ];

      final metrics = calculateFunnelMetrics(stages, []);

      expect(metrics[0].stage.name, 'Lead');
      expect(metrics[1].stage.name, 'Qualified');
      expect(metrics[2].stage.name, 'Closed');
    });
  });
}
