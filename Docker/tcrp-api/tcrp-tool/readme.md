Readme
=======

### Getting Started

Use vwcc to renew existing certificates.
Use vwdcc to issue new certificates with a master certificate (read Wiki). These are bound to a certain domain.
Use vwicc to issue new certificates semi-automatically over myServe. These are not bound to a certain domain.
Use vwcsr to create Certificate Signing Requests.
Use tcrp-hsm to work with your certificates within an HSM (Hardware Security Module).
Use tcrp-win.exe on Windows to work with your certificates within Windows Certificate Store.
Use log-pretty to convert your log files into a format better readable.

### Configuration Files

You can put your configuration options into a yaml file.
An example yaml configuration file can be obtained like this:

 - Linux/Darwin: `./vwcc > vwcc_config.yaml`
 - Windows: `.\vwcc.exe > vwcc_config.yaml`
 
Then, open `vwcc_config.yaml` and delete the beginning of the file until and including `Reference YAML configuration:`.
This applies to **vwdcc**, **vwicc** and **vwcsr** as well.

When you have your vwcc_config.yaml you can start vwcc with:
 - Linux/Darwin: `./vwcc -Configuration vwcc_config.yaml`
 - Windows: `.\vwcc.exe -Configuration vwcc_config.yaml`


### Versioning & Compatibility

The **current** archive contains the recent versions of all the clients.
The **previous archive is the same except that vwcc, vwicc, vwdcc are the previous versions.
 
