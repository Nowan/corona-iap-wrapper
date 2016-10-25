--[[

	Module that initializes appropriate IAP services depending on device platform -
	Google Play for Android, App Store for iOS - and handles their events

	----------------------------------------------------------------------------------------------------------------

	Configuration for Android:

	1. Log in to Google Play Developer Console https://play.google.com/apps/publish/?hl=en
		1.1. Make sure your application is published
		1.2. Go to All applications->[your_application]->In-app Products to add necessary products.
			 Provide Product ID in format [application_package_name].[product_name], i.e. com.warappa.pixelprophecy.landscapes
		1.2. Go to Settings->Account details->Merchant account and create merchant account(if it's empty)
		1.3. If application is in alpha or beta test, go to Settings->Account details->License testing and
			 fill textbox with emails of testers allowed to test IAP ( [user_name], [user_name], ... )
	2. Follow the steps under "Project Settings" tab in https://docs.coronalabs.com/plugin/google-iap-v3/
	3. In future tests, sign your application with the same keystore you used for publishing.
	   The version code of an APK on a test device must match the version currently uploaded to the alpha or beta channel on Google Play.
	4. In this file, fill IAP.initialIDs property with Product IDs provided in Google Play Store, for example:
	   IAP.initialIDs = { "com.warappa.pixelprophecy.landscapes", "com.warappa.pixelprophecy.rooms" };

	----------------------------------------------------------------------------------------------------------------

	Configuration for iOS:

	1. Ask Darek to fill billing information in Apple App Store
	2. Ask Darek to provide certificate
	3. Ask Darek to create provisioning profile

	----------------------------------------------------------------------------------------------------------------
	________
	Methods:


	IAP:init() - initializes store object and loads initial products. Must be called on application very start.
	Once called, it loads products IAP.initialIDs, and parses product data in IAP.products table (described further below)

	IAP:loadProducts([productsIDs], [loadedCallback]) - loads list of products with given product identifiers (better not use, tests are missing)
	[optional] productsIDs - string array of products if nil or empty, function loads list of IAP.initialIDs
	[optional] loadedCallback(errorString) - function that fires when products loading is finished.
								   			 errorString is nil when purchase was successful, elsewise contains error message,

	IAP:purchase(product,[purchasedCallback]) - opens appropriate purchasing dialog to handle the purchase of selected product.
	[required] product - specific item from IAP.products array
	[optional] purchasedCallback(errorString) - function that fires when product purchase is finished(or cancelled).
								   				errorString is nil when purchase was successful, elsewise contains error message,
												like "product is not available" or "user cancelled purchase"

	IAP:consume(product,[consumedCallback]) - consumes selected product.
	[required] product - specific item from IAP.products array
	[optional] consumedCallback(errorString) - function that fires when product consumation is finished.
											   errorString is nil when purchase was successful, elsewise contains issue message.

	IAP:restore() - restores data abaut all purchases from the store.

	___________
	Properties:


	IAP.initialIDs - string array of products identifiers loaded by default on IAP:init()

	IAP.products - array of lua tables, each storing full data about specific product. Each table has the following fields:
		product.title - product title from store;
		product.description - product description from store;
		product.localizedPrice - product country-specific price;
		product.priceAmountMicros - price in micros format;
		product.priceCurrencyCode - currency code, like "PLN", "UAH", "EUR";
		product.isOwned - whether product was purchased by user;


	___________
	Example usage:

	-- on application very start, to load products from store
	local IAP = require("IAP");
	IAP:init();

	...

	-- when need to purchase product
	IAP:purchase(IAP.products[1], function(errorString)
		print("Purchase callback: ");
		if not errorString then
			print("Product "..IAP.products[1].title);
			print("In owned: "..IAP.products[1].isOwned);
		else
			print(errorString);
		end
	end);

]]--
local IAP = {};

local fileManager = require("FileManager"); -- dependency

--------------------------------------------------------------------------------
--	Public properties
--------------------------------------------------------------------------------

IAP.initialIDs = {
	"puzzles.landscapes",
	"puzzles.monsters",
	"puzzles.space",
	"puzzles.vehicles"
};

IAP.products = nil;

--------------------------------------------------------------------------------
--	Methods declarations
--------------------------------------------------------------------------------
local init, loadProducts, purchase, consume, restore;

function IAP:init()
	init();
end

function IAP:loadProducts(productsIDs, loadedCallback)
	loadProducts(productsIDs, loadedCallback);
end

function IAP:purchase(product, purchasedCallback)
	purchase(product, purchasedCallback);
end

function IAP:consume(product, consumedCallback)
	consume(product, consumedCallback);
end

function IAP:restore()
	restore();
end

--------------------------------------------------------------------------------
--	Private properties
--------------------------------------------------------------------------------

local store;
local json = require("json");
-- name of the file storing info about bought products
local fileName = ".commodities";
local filePath = system.CachesDirectory;
-- parsed products from cacheFileName
local cachedProducts = nil;

-- callbacks for initialized, loaded, purchased and consumed events
local lCallback, pCallback, cCallback;

--------------------------------------------------------------------------------
--	Methods initializations
--------------------------------------------------------------------------------

-- enum with current platform status
local Platform = {};
Platform.Current = system.getInfo("platformName");
Platform.Android = "Android";
Platform.iOS = "iPhone OS";

-- Transaction listener function
local function transactionListener( event )
	console.log("----------------------");
	if not ( event.transaction.state == "failed" or event.transaction.state=="cancelled" ) then  -- Successful transaction
		local productID = event.transaction.productIdentifier;
		local productState = tostring(event.transaction.state);

		-- find product by id and change "isOwned" state
		for p=1,#IAP.products do
			if(IAP.products[p].productIdentifier==productID) then
				local boolState = productState=="purchased" and true or false;
				IAP.products[p].isOwned = boolState;
			end
		end

		-- fire purchased callback if provided
		if pCallback then
			pCallback();
			pCallback = nil;
		end
		-- fire consumed callback if provided
		if cCallback then
			cCallback();
			cCallback = nil;
		end
    else
		-- fire purchased callback with error if provided
		if pCallback then
			pCallback(event.transaction.errorString);
			pCallback = nil;
		end
		-- fire consumed callback with error if provided
		if cCallback then
			cCallback(event.transaction.errorString);
			cCallback = nil;
		end
    end

	-- update list of product in cache file
	local fileContents = json.encode(IAP.products);
	fileContents = fileManager:encode(fileContents);
	fileManager:writeString(fileName, filePath, fileContents);

	if(Platform.Current==Platform.iOS) then
		-- tell the store that the transaction is finished
		store.finishTransaction( event.transaction );
	end

	for i=1,#IAP.products do
		local product = IAP.products[i];
		console:log(product.productIdentifier);
		console:log("Title: "..tostring(product.title));
		console:log("Description: "..tostring(product.description));
		console:log("Localized price: "..tostring(product.localizedPrice));
		console:log("Currency: "..tostring(product.priceCurrencyCode));
		console:log("Is owned: "..tostring(product.isOwned));
		console:log("--");
	end

	if(event.transaction.state == "restored") then
		console:log("Localized price: "..tostring(event.transaction.originalReceipt));
		console:log("Currency: "..tostring(event.transaction.originalIdentifier));
		console:log("Is owned: "..tostring(event.transaction.originalDate));
		console:log("--");
	end
end

local function productsCallback(event)
	for i=1,#event.products do
	    local product = event.products[i]
		-- find product by id and complete all product fields
		for p=1,#IAP.products do
			if(IAP.products[p].productIdentifier==product.productIdentifier) then
				IAP.products[p].title = product.title;
				IAP.products[p].description = product.description;
				IAP.products[p].localizedPrice = product.localizedPrice;
				IAP.products[p].priceAmountMicros = product.priceAmountMicros;
				IAP.products[p].priceCurrencyCode = product.priceCurrencyCode;
				IAP.products[p].isOwned = false;
				break;
			end
		end
	end

	local needsStatusCheck = false;
	if cachedProducts then
		needsStatusCheck = #cachedProducts<#IAP.products;

		-- synchronize cache file with loaded products
		for i=1, #IAP.products do
			local missedInCache = true;

			for p=1,#cachedProducts do
				if(IAP.products[i].productIdentifier==cachedProducts[p].productIdentifier) then
					IAP.products[i].isOwned = not not cachedProducts[p].isOwned; -- to boolean
					missedInCache = false;
					break;
				end
			end

			if missedInCache then
				cachedProducts[#cachedProducts+1] = IAP.products[i];
			end
		end

		cachedProducts = IAP.products;
		local fileContents = json.encode(IAP.products);
		fileContents = fileManager:encode(fileContents);
		fileManager:writeString(fileName, filePath, fileContents);

		-- if there are new products loaded - refresh purchase statuses
		if needsStatusCheck then
			IAP:restore();
		elseif lCallback then
			lCallback();
			lCallback = nil;
		end
	else
		-- restore info about purchases if there are no cached products
		-- (cache file doesn't exist or has been damaged)
		IAP:restore();
	end
end

init = function()
	-- convert IAP.products from string array to tables array
	local prevProducts = IAP.initialIDs;
	IAP.products = {};
	for i=1,#prevProducts do
		IAP.products[i] = { productIdentifier=prevProducts[i] };
	end

	local fileContents = fileManager:readString(fileName, filePath);
	if fileContents then
		fileContents = fileManager:decode(fileContents);
		local decodedProducts = json.decode( fileContents );
		if decodedProducts then
			cachedProducts = #decodedProducts==0 and nil or decodedProducts;
		end
	end

	if(Platform.Current==Platform.Android) then
		store = require("plugin.google.iap.v3");
		store.init(transactionListener);
	elseif(Platform.Current==Platform.iOS) then
		store = require("store");
		store.init(transactionListener);
	end

	IAP:loadProducts();
end

loadProducts = function(productsIDs, loadedCallback)
	lCallback = loadedCallback;

	if(Platform.Current==Platform.Android or Platform.Current==Platform.iOS) then
		if productsIDs and #productsIDs>=1 then
			store.loadProducts( productsIDs, productsCallback )
		else
			store.loadProducts( IAP.initialIDs, productsCallback )
		end
	end
end

purchase = function(product, purchasedCallback)
	if(Platform.Current==Platform.Android or Platform.Current==Platform.iOS) then
		pCallback = purchasedCallback;
		store.purchase( product.productIdentifier );
	end
end

consume = function(product, consumedCallback)
	cCallback = consumedCallback;

	if(Platform.Current==Platform.Android) then
		store.consumePurchase( product.productIdentifier );
	elseif(Platform.Current==Platform.iOS) then
		if cCallback then
			cCallback("Apple does not support consuming products");
			cCallback = nil;
		end
	end
end

restore = function()
	console:log("RESTORE")
	if(Platform.Current==Platform.Android or Platform.Current==Platform.iOS) then
		store.restore();
	end
end

return IAP;
