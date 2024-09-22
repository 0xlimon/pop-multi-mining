
This guide is based on the original script by [ZunXBT](https://github.com/zunxbt), which I have modified to allow the creation of multiple wallets on the same server. You can now generate as many wallets as you need and run separate services for each.

## VPS Configuration

To start PoP mining, you can use a VPS or run it on Ubuntu on your local system. The recommended VPS configuration is as follows:

- **RAM**: 2 GB
- **Storage**: 50 GB
- **CPU**: 2 Core

If you need a VPS, you can purchase one from providers like [PQ Hosting](https://pq.hosting/en/) using cryptocurrency.

## Installation

1. Connect to your VPS or local Ubuntu system.
2. Run the following command to download and execute the script:

   ```bash
   [ -f "hemixyz.sh" ] && rm hemixyz.sh; wget -q https://raw.githubusercontent.com/0xlimon/pop-mining/refs/heads/main/hemixyz.sh && chmod +x hemixyz.sh && ./hemixyz.sh
   ```

3. When prompted, enter the number of wallets you want to create. The script will generate the wallets and create a separate service for each one.

4. The details of each wallet will be saved in separate files named popm-address-X.json (where X is the wallet number). Please copy all the wallet details from these files and save them in a secure place.

## PoP Mining Logs

To check the mining logs for a specific wallet service, use the following command, replacing `X` with the wallet number:

```bash
sudo journalctl -u hemi-X.service -f -n 50
```

This command will show you the latest 50 log entries for the specified wallet service.

## Overall Stats

You can monitor the PoP mining status for each of your wallets by visiting [this website](https://popmining.xyz) and entering your PoP mining BTC address.

## Additional Information

- Each service is named `hemi-X.service`, where `X` is the number corresponding to the wallet.
- All services are automatically started and enabled after they are created. You can stop or restart them individually if needed.

## Contributions & Credits

This guide is an enhancement of the original script by [ZunXBT](https://github.com/zunxbt). Many thanks to [ZunXBT](https://github.com/zunxbt) for the initial setup and configuration guide!

If you encounter any issues or have suggestions, feel free to reach out or open an issue on this repository.

Happy Mining!
