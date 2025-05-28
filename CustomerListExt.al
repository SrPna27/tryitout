pageextension 50149 CustomerOption extends "Sales Order"
{
    actions
    {
        addlast(processing)
        {
            action(PayPalPayment)
            {
                ApplicationArea = All;
                Caption = 'PayPal Payment';
                Image = PaymentJournal;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;

                trigger OnAction()
                var
                    Client: HttpClient;
                    Request: HttpRequestMessage;
                    Response: HttpResponseMessage;
                    RequestHeaders: HttpHeaders;
                    Content: HttpContent;
                    ContentHeaders: HttpHeaders;
                    ResponseText: Text;
                    RequestBody: Text;
                    Url: Text;
                    ClientId: Text;
                    ClientSecret: Text;
                    OrderId: Text;
                    EncodedCredentials: Text;
                    Base64Convert: Codeunit "Base64 Convert";
                    JsonObject: JsonObject;
                    JsonToken: JsonToken;
                    AccessToken, AT, OrdID : Text;
                    PayPalMgr: Codeunit "PayPal Manager";
                    OrderHandler: Codeunit CreateOrderHandler;
                    ConfirmHandler: Codeunit ConfirmPaymentHandler;
                    AuthorizeHandler: Codeunit AuthorizePaymentHandler;
                    CaptureHandler: Codeunit CaptureAuthorizePayment;
                    AuthorizationId: Text;
                    PaymentStatus: Text;
                    CaptureId: Text;
                begin
                    // Step 1: Generate Access Token
                    Url := 'https://api-m.sandbox.paypal.com/v1/oauth2/token';

                    // AT := 'A21AAIMZ21dufQt5k0hQqU-FcAoLlDZSiTT-CuY5eAYstEkoRYUjLOMnfnOfD9aIGq4-IFZLFXrfx_IZVGfagyt--nEMLdzbw';
                    // OrdID := '70U566445L673821X';

                    ClientId := PayPalMgr.GetClientId();
                    ClientSecret := PayPalMgr.GetClientSecret();

                    Request.Method := 'POST';
                    Request.SetRequestUri(Url);

                    Request.GetHeaders(RequestHeaders);
                    EncodedCredentials := Base64Convert.ToBase64(ClientId + ':' + ClientSecret);
                    RequestHeaders.Add('Authorization', 'Basic ' + EncodedCredentials);

                    RequestBody := 'grant_type=client_credentials';
                    Content.WriteFrom(RequestBody);

                    Content.GetHeaders(ContentHeaders);
                    ContentHeaders.Clear();
                    ContentHeaders.Add('Content-Type', 'application/x-www-form-urlencoded');

                    Request.Content := Content;

                    if Client.Send(Request, Response) then begin
                        if Response.IsSuccessStatusCode() then begin
                            Response.Content.ReadAs(ResponseText);

                            if JsonObject.ReadFrom(ResponseText) then begin
                                if JsonObject.Get('access_token', JsonToken) then begin
                                    AccessToken := JsonToken.AsValue().AsText();

                                    if AccessToken <> '' then begin
                                        OrderId := OrderHandler.CreateOrder(AccessToken);
                                        if OrderId <> '' then begin
                                            PaymentStatus := ConfirmHandler.ConfirmPayment(AccessToken, OrderId);
                                            if PaymentStatus = 'APPROVED' then begin
                                                AuthorizationId := AuthorizeHandler.AuthorizePayment(AccessToken, OrderId);
                                                if AuthorizationId <> '' then begin
                                                    CaptureId := CaptureHandler.CaputurePayment(AccessToken, AuthorizationId)
                                                end
                                            end else
                                                Message('Payment status is not Approved');
                                        end;
                                    end;
                                end;
                            end;
                        end else
                            Message('API call failed with status: %1', Response.HttpStatusCode());
                    end else
                        Message('Failed to connect to the API endpoint');
                end;
            }
        }
    }
}


