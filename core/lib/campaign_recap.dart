import 'kronikas_core.dart';

String buildCampaignRecap(Chronicle chronicle, Adventure selected) {
  final campaignId = selected.campaignId;
  final title = campaignId == null
      ? selected.title
      : chronicle.campaigns[campaignId]!.name;
  final adventures = campaignId == null
      ? [selected]
      : chronicle.adventures.values.where(
          (item) => item.campaignId == campaignId,
        );
  final timeline = [
    for (final adventure in adventures)
      for (final session in adventure.sessions.values)
        if (!session.isOpen) (adventure: adventure, session: session),
  ]..sort((a, b) => a.session.startedAt.compareTo(b.session.startedAt));
  final paragraphs = <String>[title];
  for (final entry in timeline) {
    final events = entry.session.events.where(
      (event) =>
          event.visibility == EventVisibility.publishable &&
          event.milestoneStatus != MilestoneStatus.skipped,
    );
    if (events.isEmpty) continue;
    final date = entry.session.startedAt
        .toLocal()
        .toIso8601String()
        .split('T')
        .first;
    paragraphs.add(
      [
        if (campaignId == null) date else '${entry.adventure.title} · $date',
        ...events.map((event) => event.description),
      ].join('\n'),
    );
  }
  return paragraphs.length == 1 ? '' : paragraphs.join('\n\n');
}
