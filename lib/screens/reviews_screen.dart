import 'package:flutter/material.dart';

import '../models.dart';
import '../services/api_service.dart';
import '../theme.dart';

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  late Future<Map<String, dynamic>> _future;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _future = ApiService.instance.getReviews(page: _page);
  }

  void _reload() {
    setState(() => _future = ApiService.instance.getReviews(page: _page));
  }

  Future<void> _loadMore(int nextPage) async {
    setState(() => _page = nextPage);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FT.bg,
      appBar: AppBar(title: const Text('Reviews', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
      body: GlassBackground(
        child: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2.4, color: FT.green700));
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 44, color: FT.inkSoft),
                  const SizedBox(height: 12),
                  Text(ApiService.errorMessage(snapshot.error), style: const TextStyle(fontSize: 13, color: FT.inkSoft)),
                  const SizedBox(height: 16),
                  FTButton(label: 'Retry', onTap: _reload, icon: Icons.refresh_rounded),
                ],
              ),
            );
          }
          final data = snapshot.data!;
          final reviews = (data['data'] as List? ?? [])
              .map((e) => RiderReview.fromJson(e as Map<String, dynamic>))
              .toList();
          final total = data['total'] ?? reviews.length;
          final lastPage = data['last_page'] ?? 1;
          if (reviews.isEmpty) {
            return Center(
              child: emptyState(Icons.star_outline_rounded, 'No reviews yet', 'Customer reviews will appear here.'),
            );
          }
          return RefreshIndicator(
            color: FT.green700,
            backgroundColor: FT.white,
            onRefresh: () async => _reload(),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              itemCount: reviews.length + 1,
              itemBuilder: (context, i) {
                if (i == reviews.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _page >= lastPage
                        ? Center(child: Text('$total reviews', style: const TextStyle(fontSize: 11, color: FT.inkSoft)))
                        : FTButton(label: 'Load more', onTap: () => _loadMore(_page + 1), icon: Icons.expand_more_rounded),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _reviewCard(reviews[i]),
                );
              },
            ),
          );
        },
        ),
      ),
    );
  }

  Widget _reviewCard(RiderReview r) {
    return FTCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: FT.green50, shape: BoxShape.circle),
                child: Text(
                  (r.customerName ?? 'C').isEmpty ? 'C' : (r.customerName ?? 'C')[0].toUpperCase(),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: FT.green700),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.customerName ?? 'Customer', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: FT.ink)),
                    Text(timeAgoStr(r.createdAt), style: const TextStyle(fontSize: 11, color: FT.inkSoft)),
                  ],
                ),
              ),
              Row(
                children: List.generate(5, (i) => Icon(
                      i < r.rating ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 17,
                      color: i < r.rating ? FT.gold : FT.line,
                    )),
              ),
            ],
          ),
          if (r.comment != null && r.comment!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(r.comment!, style: const TextStyle(fontSize: 12.5, color: FT.ink, height: 1.4)),
          ],
        ],
      ),
    );
  }
}
