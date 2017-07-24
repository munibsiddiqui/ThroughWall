//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import "SimplePing.h"
#import "PAirSandbox.h"
#import <openssl/pkcs7.h>
#import <openssl/x509.h>
#import <openssl/asn1.h>

char *pkcs7_d_char(PKCS7 *ptr);
ASN1_OCTET_STRING *pkcs7_d_data(PKCS7 *ptr);
PKCS7_SIGNED *pkcs7_d_sign(PKCS7 *ptr);
PKCS7_ENVELOPE *pkcs7_d_enveloped(PKCS7 *ptr);
PKCS7_SIGN_ENVELOPE *pkcs7_d_signed_and_enveloped(PKCS7 *ptr);
PKCS7_DIGEST *pkcs7_d_digest(PKCS7 *ptr);
PKCS7_ENCRYPT *pkcs7_d_encrypted(PKCS7 *ptr);
ASN1_TYPE *pkcs7_d_other(PKCS7 *ptr);

char *pkcs7_d_char(PKCS7 *ptr) { return ptr->d.ptr; }
inline ASN1_OCTET_STRING *pkcs7_d_data(PKCS7 *ptr) { return ptr->d.data; }
inline PKCS7_SIGNED *pkcs7_d_sign(PKCS7 *ptr) { return ptr->d.sign; }
inline PKCS7_ENVELOPE *pkcs7_d_enveloped(PKCS7 *ptr) { return ptr->d.enveloped; }
inline PKCS7_SIGN_ENVELOPE *pkcs7_d_signed_and_enveloped(PKCS7 *ptr) { return ptr->d.signed_and_enveloped; }
inline PKCS7_DIGEST *pkcs7_d_digest(PKCS7 *ptr) { return ptr->d.digest; }
inline PKCS7_ENCRYPT *pkcs7_d_encrypted(PKCS7 *ptr) { return ptr->d.encrypted; }
inline ASN1_TYPE *pkcs7_d_other(PKCS7 *ptr) { return ptr->d.other; }
