import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// One public wallet and its network label for the optional donation screen.
class DonationWallet {
  const DonationWallet({
    required this.currency,
    required this.network,
    required this.address,
  });

  final String currency;
  final String network;
  final String address;
}

/// Reusable read-only crypto donation page. Wallet addresses are public data.
class CryptoDonationPage extends StatelessWidget {
  const CryptoDonationPage({
    super.key,
    required this.wallets,
    this.title = 'Help us! / Donate',
    this.message = 'Support independent development with an optional donation.',
  });

  final List<DonationWallet> wallets;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Icon(Icons.volunteer_activism_rounded, size: 56, color: color),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          for (final wallet in wallets)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.currency_exchange_rounded, color: color),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${wallet.currency} · ${wallet.network}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    QrImageView(
                      data: wallet.address,
                      version: QrVersions.auto,
                      size: 192,
                      padding: const EdgeInsets.all(10),
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            wallet.address,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copy address',
                          icon: const Icon(Icons.copy_rounded),
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: wallet.address),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Address copied')),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            'Check the network carefully before sending. Transactions cannot be reversed.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
