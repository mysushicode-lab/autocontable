
//<span title="Cliquer pour masquer" id="hideLink" onclick="toggleList('maListe');" style="cursor: pointer;">[X]</span>
function toggleList(elementId) {
    // Ciblez l'élément par son ID
    var element = document.getElementById(elementId);

    // Vérifiez si l'élément est actuellement visible
    if (element.style.display !== "none") {
        // Si il est visible, masquez-le
        element.style.display = "none";
    } else {
        // Sinon, affichez-le
        element.style.display = "block";
    }
}

document.addEventListener('contextmenu', function(e) {
    var target = e.target;

    // Trouver le parent <li> le plus proche avec un parent <ul> ayant la classe "wrapper1"
    while (target && (target.nodeName !== 'LI' || !target.parentNode.classList.contains('wrapper1'))) {
        target = target.parentNode;
    }

    // Si aucun élément <li> n'est trouvé ou s'il n'a pas de parent <ul> avec la classe "wrapper1", laisser le clic droit se comporter normalement
    if (!target) {
        return;
    }

    e.preventDefault();

    // Retirer la surbrillance de toutes les autres lignes
    var highlightedItems = document.querySelectorAll('.listitem3.highlight');
    highlightedItems.forEach(function(item) {
        item.classList.remove('highlight');
    });

    // Ajouter la surbrillance à la ligne cliquée
    if (target.classList.contains('listitem3')) {
        target.classList.add('highlight');
    }
});





//
//envoie une requête au serveur avec post_data en payload
//
var send_xmlhttprequest2 = function (handler, post_data) {

    var xhr_object = null;
    
	var racine_id = getRacineFromCookie();

    if (!racine_id) {
        alert("La valeur de 'racine' n'a pas été trouvée dans le cookie.");
        return;
    }
    
    if(window.XMLHttpRequest) // Firefox

	xhr_object = new XMLHttpRequest();

    else if(window.ActiveXObject) // Internet Explorer

	xhr_object = new ActiveXObject("Microsoft.XMLHTTP");

    else { // XMLHttpRequest non supporté par le navigateur

	alert("Votre navigateur ne supporte pas les objets XMLHTTPRequest...");

	return;

    }

    xhr_object.open("POST", "/"+racine_id+"/xmlhttprequest/"+handler, true);

    xhr_object.onreadystatechange = function anonymous() {

	if(xhr_object.readyState == 4) {

	    eval(xhr_object.responseText);

	}

    }

    xhr_object.setRequestHeader("Content-type", "application/x-www-form-urlencoded");

    var data = post_data;

    xhr_object.send(data);

}

var send_xmlhttprequest3 = function (handler, post_data, callback) { // Ajout d'un paramètre callback

    var xhr_object = null;

    var racine_id = getRacineFromCookie();

    if (!racine_id) {
        alert("La valeur de 'racine' n'a pas été trouvée dans le cookie.");
        return;
    }

    if (window.XMLHttpRequest) // Firefox
        xhr_object = new XMLHttpRequest();
    else if (window.ActiveXObject) // Internet Explorer
        xhr_object = new ActiveXObject("Microsoft.XMLHTTP");
    else { // XMLHttpRequest non supporté par le navigateur
        alert("Votre navigateur ne supporte pas les objets XMLHTTPRequest...");
        return;
    }

    xhr_object.open("POST", "/" + racine_id + "/xmlhttprequest/" + handler, true);

    xhr_object.onreadystatechange = function() { // Modification de la syntaxe de la fonction de rappel
		 //console.log("XHR state: " + xhr_object.readyState); // Affiche l'état du XHR dans la console
        if (xhr_object.readyState == 4) {
			//console.log("XHR status: " + xhr_object.status); // Affiche le statut HTTP dans la console
            // Vérifiez si la réponse est OK (statut HTTP 200)
            if (xhr_object.status == 200) {
                // Utilisez le callback pour traiter la réponse
                if (callback) {
                    callback(xhr_object.responseText);
                }
            } else {
                // Gérez les erreurs HTTP ici si nécessaire
                console.error("Erreur HTTP : " + xhr_object.status);
            }
        }
    };

    xhr_object.setRequestHeader("Content-type", "application/x-www-form-urlencoded");

    var data = post_data;

    xhr_object.send(data);
}

//
//envoie une requête au serveur avec post_data en payload
//
var send_xmlhttprequest = function (handler, post_data) {

    var xhr_object = null;
    
	var racine_id = racine.value;
	
    if(window.XMLHttpRequest) // Firefox

	xhr_object = new XMLHttpRequest();

    else if(window.ActiveXObject) // Internet Explorer

	xhr_object = new ActiveXObject("Microsoft.XMLHTTP");

    else { // XMLHttpRequest non supporté par le navigateur

	alert("Votre navigateur ne supporte pas les objets XMLHTTPRequest...");

	return;

    }

    xhr_object.open("POST", "/"+racine_id+"/xmlhttprequest/"+handler, true);

    xhr_object.onreadystatechange = function anonymous() {

	if(xhr_object.readyState == 4) {

	    eval(xhr_object.responseText);

	}

    }

    xhr_object.setRequestHeader("Content-type", "application/x-www-form-urlencoded");

    var data = post_data;

    xhr_object.send(data);

}

// Fonction pour récupérer la valeur de la variable "racine" depuis les cookies
function getRacineFromCookie() {
    var cookies = document.cookie.split(';'); // Sépare les cookies en un tableau

    //console.log("Liste des cookies disponibles :");
    for (var i = 0; i < cookies.length; i++) {
        var cookie = cookies[i].trim(); // Supprime les espaces autour du cookie
        //console.log(cookie);
        if (cookie.startsWith('racine=')) { // Recherche le cookie "racine"
            var racineCookie = cookie.substring(7); // Extrait la valeur après le signe égal
            //console.log("Cookie 'racine' trouvé : " + racineCookie);
            return racineCookie; // Retourne la valeur de "racine"
        }
    }
    //console.log("Le cookie 'racine' n'a pas été trouvé.");
    return null; // Retourne null si le cookie "racine" n'est pas trouvé
}

//
//renseigne la datalist des comptes quand l'utilisateur tape un ou des chiffres
//
var renseigner_compte = function(my_numero_compte, my_line) {

    //empêcher une validation directe du formulaire sans staging
//    invalidate_form();
    
    var id_line = my_line;

    var numero_compte = my_numero_compte;

    var data = "numero_compte_datalist="+numero_compte+"&id_line="+id_line;

    send_xmlhttprequest("entry_helper", data);

} // var renseigner_compte = function(my_numero_compte, my_line) 

//
//renseigne la datalist des comptes quand l'utilisateur tape un ou des chiffres
//
var renseigner_doc = function(my_documents, my_line) {

    //empêcher une validation directe du formulaire sans staging
	//    invalidate_form();
    
    var id_line = my_line;

    var documents = my_documents;

    var data = "name_doc_datalist="+documents+"&id_line="+id_line;

    send_xmlhttprequest("entry_helper", data);

} // var renseigner_doc = function(my_id_name, my_line) 

//renseigne la datalist des comptes quand l'utilisateur tape un ou des chiffres
//
var renseigner_libre = function(my_libre, my_line) {

    //empêcher une validation directe du formulaire sans staging
	//invalidate_form();
    
    var id_line = my_line;

    var libre = my_libre;

    var data = "name_libre_datalist="+libre+"&id_line="+id_line;

    send_xmlhttprequest("entry_helper", data);

} // var renseigner_libre = function(my_id_name, my_line) 

//
//vide la dataliste de parent_id quand l'utilisateur modifie sa saisie, pour éviter que les anciennes valeurs ne s'affichent en plus des nouvelles
//
var clearChildren = function (parent_id) {

    var parent = document.getElementById(parent_id);

    var childArray = parent.children;

    var cL = childArray.length;

    while(cL > 0) {

	cL--;

	parent.removeChild(childArray[cL]);
    }
    
} // var clearChildren = function (parent_id) 

//
//recopie la valeur du controle de la ligne précédente quand l'utilisateur tape un espace
//utilisé dans date_ecriture, id_facture, libelle
//
var copy_previous_input = function (input, previous_line_number) {

    //les id des contrôles sont au format 'nom_du_controle_1234'; on splite sur le dernier _
    var res = input.id.match(/(.*_)(\d+)/);
    //la première valeur de res contient nom_du_controle
    var id_input = res[1];

    //on copie la valeur la ligne précédente si l'utilisateur a tapé un espace
    if ( input.value.match(/^\s/) ) { 

	input.value = document.getElementById(id_input + previous_line_number).value;
	
	// on doit ajouter stage(input) pour Chrome qui ne déclenche pas onchange après oninput
	stage(input) ;
	
    };

} //var copy_previous_input = function (input, previous_line_number) 

//
//stocke la valeur de l'input dans la table tbljournal_staging
//
var stage = function (input) {

    var _token_id = document.getElementById("_token_id").value;
    
    //les id des contrôles sont au format 'nom_du_controle_1234'; on splite sur le dernier _
    var res = input.id.match(/(.*_)(\d+)/);

    //la première valeur de res contient id_du_controle; on strippe le dernier _
    var id_input = res[1].substring(0, res[1].lastIndexOf("_"));

    //la deuxième valeur de res contient le numero de ligne à modifier
    var id_line = res[2];

    var my_value;

    //pour les colonnes débit/crédit, supprimer le formatage, remplacer la virgule par un point
    var re = /debit|credit/;

    if ( input.id.match(re) ) {

    	my_value = input.value.replace(/\s/g, "");

    } else {

    	my_value = input.value;

    }

    //il faut encoder la valeur sinon ça ne passe pas pour les caractères accentués
    var data = "stage="+input.id+"&value="+encodeURIComponent(my_value)+"&_token_id="+_token_id;

    send_xmlhttprequest("entry_helper", data);

} //var stage = function(input)

//
//ajoute un message dans la div id_bad_input en haut du formulaire et ajoute class=bad_input à l'élément input concerné
//
var signal_bad_input = function(input_id) {

    var input = document.getElementById(input_id);

    var p = document.createElement('p'); 

    p.id = "bad_input_"+input_id;

    p.textContent = "Valeur non valide : "+input.value;

    p.setAttribute("class", "warning");

    document.getElementById("bad_input").appendChild(p);

    input.focus();

    input.setAttribute("class", "bad_input");

    validate_this.disabled = true;


} //    var signal_bad_input = function(input) 

//
//ajoute un message dans la div id_bad_input en haut du formulaire et ajoute class=bad_input à l'élément input concerné
//
var signal_bad_date_input = function(input_id, error) {

    var input = document.getElementById(input_id);
    
    var id_error = error;
    
    //s'il existe des valeurs non valides, leur attribut class=bad_input
    if ( input.getAttribute("class") === "bad_input" ) {

	//on retire l'input de la liste dans bad_input
	bad_input.removeChild(document.getElementById("bad_input_"+input.id));
	}

    var p = document.createElement('p'); 

    p.id = "bad_input_"+input_id;
    
    if (id_error === "manquant"){
	p.textContent = "Date manquante "+input.value;
	} else if (id_error === "fiscal"){
	p.textContent = "Vérifier que la date soit dans le bon exercice fiscal : "+input.value;
	} else {
    p.textContent = "Vérifier que la date soit dans le bon format ( jjmm ou jjmmaaaa ou jj mm aaaa ou jj/mm/aaaa ): "+input.value;
	}
	
    p.setAttribute("class", "warning");
    
    document.getElementById("bad_input").appendChild(p);
    
    input.focus();

    input.setAttribute("class", "bad_input");

    validate_this.disabled = true;


} //    var signal_bad_date_input = function(input, error) 

//
//si stage() s'est bien passé, sort l'input de la liste des bad_input et réactive le bouton Valider si la liste est vide
//
var rehab_bad_input = function(id_input) {

    var input=document.getElementById(id_input);

    //s'il existe des valeurs non valides, leur attribut class=bad_input
    if ( input.getAttribute("class") === "bad_input" ) {

	//on retire l'input de la liste dans bad_input
	bad_input.removeChild(document.getElementById("bad_input_"+input.id));

	input.setAttribute("class", "good_input");

	//si bad_input est vide, on peut réactiver le bouton 'Valider'
	if (document.getElementsByClassName("bad_input").length==0) {

	    bad_input.textContent = "";

	    validate_this.disabled = false

	} else {

	    validate_this.disabled = true;

	}

    }
    
} // var rehab_bad_input = function(id_input)

//
//formate un debit/credit sur 2 décimale et l'enregistre dans staging; formate une date raccourcie avec format_date
//
var format_and_stage = function(input) {
	
	if ( input.name.match(/montant/) ) {
	//remplacer les séparateurs de milliers, et la virgule éventuelle des décimales	
	var raw_value = input.value.replace(/\s/g, "").replace(/,/, ".");
	//signaler l'erreur si on a pas un nombre valide
	if ( isNaN(Number(raw_value)) ) {
    signal_bad_input(input.id);
	} else {
	    //le nombre est valide; le reformatter et l'envoyer à stage
	    input.value = Number(raw_value).toLocaleString('fr-FR', {minimumFractionDigits: 2}).replace(/,/, ".");
	}}

    //debit ou credit
    if ( input.name.match(/debit|credit/) ) {

	//remplacer les séparateurs de milliers, et la virgule éventuelle des décimales	
	var raw_value = input.value.replace(/\s/g, "").replace(/,/, ".");

	//signaler l'erreur si on a pas un nombre valide
	if ( isNaN(Number(raw_value)) ) {
	    
	    signal_bad_input(input.id);
	    
	} else {

	    //le nombre est valide; le reformatter et l'envoyer à stage
	    input.value = Number(raw_value).toLocaleString('fr-FR', {minimumFractionDigits: 2}).replace(/,/, ".");

	    stage(input);

	}

    }

    //date_ecriture
    if ( input.name.match(/date_ecriture/) ) {
		
	//enforce YYYY format
	var my_re = /^(\d\d).(\d\d).(\d\d)$/;

	var NOT_OK = my_re.exec(input.value);

	if ( NOT_OK ) {

	    signal_bad_date_input(input.id, "erreur");

	} else {
	    
	    format_date(input, preferred_datestyle.value);
	    
	    stage(input);

    }
	}
    
} //var format_and_stage = function(input) 

//formate un debit/credit sur 2 décimale
//
var format_number = function(input) {
	
	if ((input.value !== undefined) && (input.value !== null) && (input.value!== "")) {

		//remplacer les séparateurs de milliers, et la virgule éventuelle des décimales	
		var raw_value = input.value.replace(/\s/g, "").replace(/,/, ".");

		//signaler l'erreur si on a pas un nombre valide
		if ( isNaN(Number(raw_value)) ) {
			//signal_bad_input(input.id);
		} else {
			//le nombre est valide; le reformatter et le renvoyer
			input.value = Number(raw_value).toLocaleString('fr-FR', {minimumFractionDigits: 2}).replace(/,/, ".");
		}
	} 
		
} //var format_number = function(input) 

//verification date obligatoire
var verifdt = function(input) {
	if ((input.value !== undefined) && (input.value !== null) && (input.value!== "") ) {
    
    // First check for the pattern
    var date_dd_mm_yyyy = /^\d{1,2}\/\d{1,2}\/\d{4}$/;
    //enforce YYYY format
	var date_ddmm = /^(\d\d).?(\d\d)$/;
	var date_ddmmyy = /^(\d\d).(\d\d).(\d\d)$/;
	var date_ddmmyyyy = /^\d{1,2}\.?\d{1,2}\.?\d{4}$/;

    if ((date_dd_mm_yyyy.test(input.value)) || 
    (date_ddmm.test(input.value)) || 
    (date_ddmmyyyy.test(input.value)) || 
    (!date_ddmmyy.test(input.value)) ){
	format_date(input, preferred_datestyle.value);
	stage(input);
    } else {
	signal_bad_date_input(input.id, "erreur");
	}

} else {
	// Si la date est manquante, afficher erreur date
	//signal_bad_date_input(input.id, "manquant");
	
    // Si la date est manquante, mettre la date du jour dans l'input
    var currentDate = new Date();
    var day = ("0" + currentDate.getDate()).slice(-2);
    var month = ("0" + (currentDate.getMonth() + 1)).slice(-2);
    var year = currentDate.getFullYear();
    var formattedDate = day + '/' + month + '/' + year;
    input.value = formattedDate;

    // Continuez avec le reste de votre logique si nécessaire
    format_date(input, preferred_datestyle.value);
    stage(input);
	}
}

// Formate une date raccourcie "0104" en 2016-04-01, "01042022" en 2022-04-01 et "010422" en 2022-04-01
var format_date = function(input, preferred_datestyle) {
    
    // On accepte dd?mm (le jour et le mois sur deux chiffres, éventuellement séparés par un caractère)
    var my_re = /^(\d\d).?(\d\d)$/;
    var my_re2 = /^(\d\d).?(\d\d).?(\d\d\d\d)$/;
    var my_re3 = /^(\d\d).?(\d\d).?(\d\d)$/;  // Pour le format ddmmyy

    var OK = my_re.exec(input.value);
    var OK2 = my_re2.exec(input.value);
    var OK3 = my_re3.exec(input.value);

    if (OK) {
        
        var today = new Date();
        var yyyy = today.getFullYear();
        var mm = ("0" + OK[2]).slice(-2);
        var dd = ("0" + OK[1]).slice(-2);

        if (preferred_datestyle === 'iso') {
            input.value = yyyy + "-" + mm + "-" + dd;
        } else {
            input.value = dd + "/" + mm + "/" + yyyy;
        }
    } else if (OK2) {
        
        var yyyy2 = OK2[3];
        var mm2 = ("0" + OK2[2]).slice(-2);
        var dd2 = ("0" + OK2[1]).slice(-2);

        if (preferred_datestyle === 'iso') {
            input.value = yyyy2 + "-" + mm2 + "-" + dd2;
        } else {
            input.value = dd2 + "/" + mm2 + "/" + yyyy2;
        }
    } else if (OK3) {
        
        var today = new Date();
        var current_century = Math.floor(today.getFullYear() / 100) * 100;
        var yy = parseInt(OK3[3], 10);
        var yyyy3 = yy + (yy < 50 ? current_century : current_century - 100);
        var mm3 = ("0" + OK3[2]).slice(-2);
        var dd3 = ("0" + OK3[1]).slice(-2);

        if (preferred_datestyle === 'iso') {
            input.value = yyyy3 + "-" + mm3 + "-" + dd3;
        } else {
            input.value = dd3 + "/" + mm3 + "/" + yyyy3;
        }
    }
}


//vérification de la balance : si l'opération est déséquilibrée, le bouton valider est désactivée
//déclenchée après une modification de debit|credit
var check_balance = function() {

    var array_debit = document.getElementsByName("debit");

    var total_debit = 0;

    var array_credit = document.getElementsByName("credit");

    var total_credit = 0;

    //on totalise les colonnes debit/credit
    //les nombres ont tous été formatés sur deux décimales, on peut donc retirer le point décimal pour travailler avec des entiers
    for (i=0; i<array_credit.length; i++){

	total_debit = total_debit + Number(array_debit[i].value.replace(/\s/g, "").replace(/\./,""));

	total_credit = total_credit + Number(array_credit[i].value.replace(/\s/g, "").replace(/\./,""));
	
    };

    var solde = total_credit - total_debit;
    
    document.getElementById("total_debit").value = (Number(total_debit)/100).toLocaleString('fr-FR', {minimumFractionDigits: 2}).replace(/,/, ".");

    document.getElementById("total_credit").value = (Number(total_credit)/100).toLocaleString('fr-FR', {minimumFractionDigits: 2}).replace(/,/, ".");

    document.getElementById("total_solde").value = (Number(solde)/100).toLocaleString('fr-FR', {minimumFractionDigits: 2}).replace(/,/, ".");

    //l'opération est déséquilibrée
    if ( solde ) {

	document.getElementById("total_solde").setAttribute("class", "bad_input");

	validate_this.disabled = true;

    } else {

	document.getElementById("total_solde").setAttribute("class", "good_input");

	//l'opération est équilibrée; vérifier qu'il n'y a pas de bad_input avant de réactiver le bouton 'Valider'
	if (document.getElementsByClassName("bad_input").length==0) { 	
	    
	    validate_this.disabled = false;

	}

    }

} //var check_balance = function() 

//var calculer_id_facture = function (input, open_journal, libelle_journal_type) {
var calculer_id_facture = function (input, open_journal) {

    //on copie la valeur la ligne précédente si l'utilisateur a tapé un espace
    if ( input.value.match(/^\s/) ) { 

	//les id des contrôles sont au format 'nom_du_controle_1234'; on splite sur le dernier _
	var res = input.id.match(/(.*_)(\d+)$/);
	//la première valeur de res contient nom_du_controle
	var id_input = res[1];

	//la deuxième valeur contient le numero de ligne
	var id_line = res[2];

	var date_ecriture = document.getElementById("date_ecriture_"+id_line).value;

	if ( date_ecriture ) {
	    
	    var data = "calculer_numero_piece="+input.id+"&date_ecriture="+date_ecriture+"&open_journal="+open_journal;

	    send_xmlhttprequest("entry_helper", data);

	} else {

	    input.value = "Date absente!"

	}

    } //    if ( input.value.match(/^\s/) ) 
    
} //var calculer_id_facture 

// Fonction pour mettre le focus sur un élément et changer sa couleur
function focusAndChangeColor(input) {
    var selectElement = document.getElementById("line_"+input);
    if (selectElement) {
        Yelloback(selectElement.id);
        selectElement.focus();
    }
}

// Fonction pour mettre le focus sur un élément et changer sa couleur
function focusAndChangeColor2(input) {
    var selectElement = document.getElementById("line_"+input);
    if (selectElement) {
		selectElement.classList.replace("listitem3", "listitem2");
    }
}

// Fonction pour mettre le focus sur un élément et changer sa couleur
function focusAndChangeColor3(input) {
    var selectElement = document.getElementById("line_"+input);
    if (selectElement) {
		selectElement.classList.add("listitem2");
    }
}
		
function encryptTextArea() {
	var key = "your_secret_key";
	var text = document.getElementById("csv_content").value;

	// Chiffrement XOR
	var encryptedText = encryptXOR(text, key);

	// Encodage en base64
	var base64Text = btoa(encryptedText);

	// Mettre le texte encodé en base64 dans le champ de formulaire caché
	document.getElementById("encrypted_script_csv").value = base64Text;
			
	// Supprimez complètement le champ csv_content
	document.getElementById("csv_content").remove();
			
}

function encryptTxtArea(...elements) {
    // Clé de chiffrement définie à l'intérieur de la fonction
    const key = "your_secret_key";

    // Vérifier si le nombre d'arguments est pair (éditeur + champ chiffré)
    if (elements.length % 2 !== 0) {
        console.error("Nombre d'arguments incorrect. Vous devez passer des paires d'éléments (éditeur, champ chiffré).");
        return false;
    }

    // Parcourir les éléments par paires (éditeur et champ chiffré)
    for (let i = 0; i < elements.length; i += 2) {
        let editorId = elements[i];
        let encryptedInputId = elements[i + 1];

        // Récupérer les éléments HTML
        let editor = document.getElementById(editorId);
        let encryptedInput = document.getElementById(encryptedInputId);

        // Vérification des éléments
        if (!editor) {
            console.error(`Élément éditeur non trouvé : ${editorId}`);
            continue;
        }
        if (!encryptedInput) {
            console.error(`Élément champ chiffré non trouvé : ${encryptedInputId}`);
            continue;
        }

        // Récupérer le contenu à chiffrer
        let text = editor.innerHTML;

        // Vérifier si le texte n'est pas vide
        if (!text) {
            console.warn(`Le contenu de l'éditeur ${editorId} est vide.`);
            continue;
        }

        // Chiffrement XOR
        let encryptedText = encryptXOR(text, key);

        // Convertir le texte chiffré en hexadécimal
        let hexEncryptedText = stringToHex(encryptedText);

        // Mettre le texte encodé en hexadécimal dans le champ de formulaire caché
        encryptedInput.value = hexEncryptedText;
    }

    return true; // Permet au formulaire de se soumettre
}

function encryptXOR(text, key) {
	var encryptedText = "";
	for (var i = 0; i < text.length; i++) {
		encryptedText += String.fromCharCode(text.charCodeAt(i) ^ key.charCodeAt(i % key.length));
	}
	return encryptedText;
}

function stringToHex(str) {
	var hex = "";
	for (var i = 0; i < str.length; i++) {
		var hexChar = str.charCodeAt(i).toString(16);
		hex += ("00" + hexChar).slice(-2);  // Assure que chaque octet est représenté par deux caractères hexadécimaux
	}
	return hex;
}

var findModif = function(input, line){
	input.classList.add('line_selected');
	var id = "valid_"+line;
	var selectElement = document.querySelector("[id=" + id + "]");
	selectElement.classList.replace("line_icon_hidden", "line_icon_visible");
	var parent = selectElement.parentNode;
	parent.classList.replace("displayspan", "blockspan");
	//selectElement.style.visibility = 'visible';
}

var Yellobri = function(input, line){
	input.classList.add('line_selected');
}

// Surbrillance si modification
var ModSelected = function(input, line = 'submit1') {
    input.classList.add('line_selected');
    
    // Utilise 'line' s'il est fourni, sinon 'submit1'
    var id = line;
    
    // Sélectionne l'élément avec l'identifiant généré
    var selectElement = document.querySelector("[id=" + CSS.escape(id) + "]");
    
    // Vérifie si l'élément existe avant d'essayer de remplacer ses classes
    if (selectElement) {
        selectElement.classList.replace("btn-vert", "btn-jaune");
    } else {
        console.error("JAVASCRIPT ERROR : ModSelected => Elément non trouvé pour l'id: " + id);
    }
};



var Yelloback = function(input){
	var element = document.getElementById(input);
	// Vérifiez si l'élément existe
	if (element) {
	  // Changez la couleur de fond de l'élément
	  element.style.backgroundColor = '#d2d504';
	}
}

var calcul_facture_total_quittance = function() {
    var total = 0;

   // Boucle à travers les champs de montant
    for (var i = 1; i <= 4; i++) {
        var variable = parseFloat(document.getElementById("facture_montant_" + i).value.replace(/\s/g, "").replace(/,/, ".")) || 0;
        total += variable;
    }

    document.getElementById("facture_total").value = total.toLocaleString('fr-FR', {minimumFractionDigits: 2}).replace(/,/, ".");
    var vartextarea = document.getElementById("textareamilieu");
    var libre = total.toFixed(2);
    
	// L'élément textarea existe, procéder au remplacement
	vartextarea.value = vartextarea.value.replace(/(somme de\s)(.*?)\seuros/g, '$1' + libre + ' euros');

    //  console.log("libre: " + libre);
    var data = "convert_chiffre_texte="+libre+"&textarea=" + encodeURIComponent(vartextarea.value);
    send_xmlhttprequest2("entry_helper", data);
    
};


var calcul_paiement_total_quittance = function() {
    var total = 0;

   // Boucle à travers les champs de montant
    for (var i = 1; i <= 6; i++) {
        var variable = parseFloat(document.getElementById("paiement_credit_" + i).value.replace(/\s/g, "").replace(/,/, ".")) || 0;
        total += variable;
    }
    
    // Boucle à travers les champs de montant
    for (var i = 1; i <= 6; i++) {
        var variable = parseFloat(document.getElementById("paiement_debit_" + i).value.replace(/\s/g, "").replace(/,/, ".")) || 0;
        total -= variable;
    }

    document.getElementById("paiement_total").value = total.toLocaleString('fr-FR', {minimumFractionDigits: 2}).replace(/,/, ".");
    
};

//convertir un chiffre en toute lettre convert_chiffre_texte
var convert_chiffre_texte = function(my_libre) {
    var libre = my_libre;
    var data = "convert_chiffre_texte="+libre;
    send_xmlhttprequest2("entry_helper", data);
}
		
var findTotal = function(input) { 
	
	//les id des contrôles sont au format \'nom_du_controle_1234\'; on splite sur le dernier _
	var res = input.id.match(/(.*_)(\d+)$/);
	//la première valeur de res contient nom_du_controle
	var id_input = res[1];

	//la deuxième valeur contient le numero de ligne
	var id_line = res[2];

	var variable1 = document.getElementById("frais_quantite_"+id_line).value;
	var variable2 = document.getElementById("frais_bareme_"+id_line).value;
	
	//console.log("findTotal pour variable1: " + variable1 + " variable2 " + variable2);

	if(variable1 != "" && variable2 != "" ) { 
	   var variable3 = parseFloat(variable1) * parseFloat(variable2);
	   document.getElementById("frais_montant_"+id_line).value = variable3.toFixed(2);
	} else {
	   document.getElementById("frais_montant_"+id_line).value = 0;
	}
}
//
//enregistrement du lettrage
//
var lettrage = function(input, numero_compte) {
	
    var data = "lettrage="+input.value+"&id_line="+input.id+"&numero_compte="+numero_compte;

    send_xmlhttprequest2("lettrage", data);

}


//
//enregistrement du pointage
//
var pointage = function(input, numero_compte, my_racine) {
	
	var data = "pointage="+input.checked+"&id_line="+input.id+"&numero_compte="+numero_compte;

send_xmlhttprequest2("lettrage", data);

}

//fonction javascript bouton options de grandlivre1 et grandlivre2 et balance
function showButtons() {
	var ecritureCloture = document.getElementById("ecriture_cloture");
    var ecritureClotureLabel = document.getElementById("ecriture_cloture_label");

    if (ecritureCloture && ecritureClotureLabel) {
        if (ecritureCloture.style.display === "inline") {
            // Les options sont actuellement visibles, les masquer
            ecritureCloture.style.display = "none";
            ecritureClotureLabel.style.display = "none";
        } else {
            // Les options sont actuellement masquées, les rendre visibles
            ecritureCloture.style.display = "inline";
            ecritureClotureLabel.style.display = "inline";
        }
	}
}
    
//
//enregistrement du pointagerecurrent
//
var pointagerecurrent = function(input, idtoken, identry) {
	
	var data = "pointagerecurrent="+input.checked+"&id_entry="+identry+"&id_token="+idtoken;

	send_xmlhttprequest2("lettrage", data);

}

//var select_contrepartie = function (input, numero_id) {
var select_contrepartie = function (input, numero_id) {
	    
	var data = "select_contrepartie="+input.value+"&numero_id="+numero_id;

	send_xmlhttprequest2("entry_helper", data);

} //var select_contrepartie

// Variable pour suivre l\'état actuel
var currentRecordIndex = 0;

// onchange="First(this, \'\', \'\', \'\', \'compte?configuration\');"
// onchange="First(this, \''.$reqid.'\', \''.$lib_journal_achats.'\', \''.$lib_journal_ventes.'\');"
function First(selectElement, reqid, lib_journal_achat, lib_journal_vente) {
	var toggleRecette = document.getElementById("saisie_recette");
    var toggleDepense = document.getElementById("saisie_depense");
    var toggleClient = document.getElementById("saisie_client");
    var toggleFournisseur = document.getElementById("saisie_fournisseur");
    var toggleTransfert = document.getElementById("saisie_transfert");
    var selected1 = document.getElementById("compte_client2_" + reqid);
    var selected2 = document.getElementById("select_achats_" + reqid);
    var selected3 = document.getElementById("compte_fournisseur2_" + reqid);
    var selected4 = document.getElementById("compte_client_" + reqid);
    
    //console.log("java_calcul_piece pour selectElement: " + selectElement.value + " selected2 " + selected2.value+ " reqid " + reqid);

    if (toggleRecette.checked && reqid && selectElement && selected1 && reqid.value !== '' && selectElement.value !== '' && selected1.value !== '') {
        java_calcul_piece(selectElement, reqid, lib_journal_vente);
    } else if (toggleDepense.checked && reqid && reqid.value !== '' && selectElement && selected3 && selectElement.value !== '' && selected3.value !== '') {
        java_calcul_piece(selectElement, reqid, lib_journal_achat);
    } else if (reqid && selectElement && selected2 && reqid.value !== '' && selectElement.value !== '' && selected2.value !== '') {
        java_calcul_piece(selected2, reqid);
    }
}

//var java_calcul_piece = function (input, numero_id, my_racine) {
var java_calcul_piece = function (input, numero_id, journal, callback) {
	
	var id_line = numero_id;
	var id_journal = (typeof journal !== 'undefined') ? journal : ''; // Utilise une chaîne vide si journal est undefined
	var id_date = document.getElementById("date_"+id_line).value;
	
	if (isValidDateddmmyyyy(id_date)) { 	

		var data = "calculer_num_piece="+encodeURIComponent(input.value)+"&date_ecriture="+id_date+"&numero_id="+id_line+"&lib_journal="+id_journal;
	
		send_xmlhttprequest3("entry_helper", data, function (response) {
			// La réponse contient le numéro de pièce calculé
			var numeroPieceInitial = response;
			
			//console.log("java_calcul_piece pour id: " + numero_id + " Pièce " + numeroPieceInitial);

			// Mettez à jour le champ via document.getElementById
			var field = document.getElementById('calcul_piece_' + numero_id);
			if (field) {
				field.value = numeroPieceInitial;
			}
			
			// Exécutez le callback avec la réponse
            if (typeof callback === 'function') {
                callback(numeroPieceInitial);
            }

		});

	} //else {
	//	alert('Vérifier la date!');
		// Rediriger le focus vers la case de date
	//	document.getElementById("date_"+id_line).focus(); 
		// Si la date n'est pas valide, appelez le callback avec null ou une valeur appropriée
    //    if (typeof callback === 'function') {
    //        callback(null);
    //    }
	//}

} //var java_calcul_piece 

//valider format de date yyyy-mm-dd
function isValidDate(dateString) {
    // First check for the pattern
    var regex_date = /^\d{4}\-\d{1,2}\-\d{1,2}$/;

    if(!regex_date.test(dateString))
    {
        return false;
    }

    // Parse the date parts to integers
    var parts   = dateString.split("-");
    var day     = parseInt(parts[2], 10);
    var month   = parseInt(parts[1], 10);
    var year    = parseInt(parts[0], 10);

    // Check the ranges of month and year
    if(year < 1900 || year > 2300 || month == 0 || month > 12)
    {
        return false;
    }

    var monthLength = [ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 ];

    // Adjust for leap years
    if(year % 400 == 0 || (year % 100 != 0 && year % 4 == 0))
    {
        monthLength[1] = 29;
    }

    // Check the range of the day
    return day > 0 && day <= monthLength[month - 1];
}

function isValidDateddmmyyyy(dateString) {
	
	    // First check for the pattern
    var regex_date = /^\d{1,2}\/\d{1,2}\/\d{4}$/;

    if(!regex_date.test(dateString))
    {
        return false;
    }
	
    // Parse the date parts to integers
    var parts = dateString.split("/");
    var day = parseInt(parts[0], 10);
    var month = parseInt(parts[1], 10);
    var year = parseInt(parts[2], 10);


    // Check the ranges of month and year
    if(year < 1900 || year > 2300 || month == 0 || month > 12)
    {
        return false;
    }
    
    var monthLength = [ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 ];

    // Adjust for leap years
    if(year % 400 == 0 || (year % 100 != 0 && year % 4 == 0))
    {
        monthLength[1] = 29;
    }

    // Check the range of the day
    return day > 0 && day <= monthLength[month - 1];
};

function verifierCaracteres(event) {
	 		
	var keyCode = event.which ? event.which : event.keyCode;
	var touche = String.fromCharCode(keyCode);
			
	var champ = document.getElementById('libelle_*');
			
	var caracteres = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
			
	if(caracteres.indexOf(touche) >= 0) {
		champ.value += touche;
	}
			
}

function verif(chars) {
    // Caractères autorisés
    //var regex = new RegExp("[a-z0-9]", "i");
    
    var regex = new RegExp("^[A-Za-zéèà0-9? ,'./\_-]+$", "i");
    var valid;
      for (x = 0; x < chars.value.length; x++) {
        valid = regex.test(chars.value.charAt(x));
        if (valid == false) {
			chars.value = chars.value.substr(0, x) + chars.value.substr(x + 1, chars.value.length - x + 1); x--;
        }
      }
}

//	my $escaped_memo1 = uri_escape_utf8($memo1);
//	<span id="help-link2" style="cursor: pointer;" onclick="ouvrirPopup(decodeURIComponent(\'' . $escaped_memo1 . '\'));">[?]</span></div>
function ouvrirPopup(contenuAide) {
			
	// Ouvrir la fenêtre popup
	popup = window.open("", "Aide", "width=1200, height=500, resizable=yes, scrollbars=yes");

	// Insérer le contenu dans la fenêtre popup
	popup.document.write(contenuAide);
		
	// Définir la fonction fermerPopup dans le contexte de la nouvelle fenêtre popup
	popup.fermerPopup = function() { popup.close(); };
			
	// Focus sur la fenêtre popup
	popup.focus();
}

function scrollToDetail(detailId) {
    var detail = document.getElementById(detailId);
    if (detail) {
        detail.scrollIntoView({ behavior: 'smooth' });
    }
}
	
//onclick="SearchDocumentation('base', 'ecriturescomptables_4')"
function SearchDocumentation(url, sectionId) {
    // Ouvrez une nouvelle fenêtre modale
    var modalWindow = window.open("", "Aide", "width=1200, height=700, resizable=yes, scrollbars=yes");

    modalWindow.document.write('<link href="/Compta/style/style.css" rel="stylesheet" type="text/css">');

    // Utilisez AJAX pour charger le contenu de la page source
    var xhr = new XMLHttpRequest();
    xhr.open('GET', url);
    xhr.onreadystatechange = function () {
        if (xhr.readyState === 4 && xhr.status === 200) {
            // Récupérez le contenu de la page source
            var pageContent = xhr.responseText;

            // Créez un élément HTML temporaire pour extraire la section cible
            var tempElement = document.createElement('div');
            tempElement.innerHTML = pageContent;

            // Recherchez la section avec l'ID spécifié
            var section = tempElement.querySelector('#' + sectionId);

            if (section) {
                // Supprimez les éléments avec la classe "label"
                var labels = section.querySelectorAll('.label');
                for (var i = 0; i < labels.length; i++) {
                    labels[i].remove();
                }

                // Injectez la section dans la fenêtre modale
                modalWindow.document.write(section.outerHTML);

                // Créez une div avec la classe "formflexN3" pour contenir le bouton "Fermer"
                var formflexN3Div = modalWindow.document.createElement('div');
                formflexN3Div.className = 'formflexN3';
                
                // Supprimez le style de padding de la classe .main-section
				var mainSection = modalWindow.document.querySelector('.main-section');
				if (mainSection) {
					mainSection.style.padding = '0'; // Remplacez la valeur du padding par 0 pour supprimer le padding
				}

                // Ajoutez un bouton "Fermer" avec l'apparence "btn btn-gris" et des styles personnalisés
                var closeButton = modalWindow.document.createElement('button');
                closeButton.textContent = 'Fermer';
                closeButton.className = 'btn btn-gris'; // Ajoutez la classe "btn btn-gris"
                closeButton.style.width = '30%'; // Définissez la largeur à 30%
                closeButton.onclick = function () {
                    modalWindow.close();
                };
                formflexN3Div.appendChild(closeButton);

                // Ajoutez la div à la fenêtre modale
                modalWindow.document.body.appendChild(formflexN3Div);

                // Ajoutez une ligne vide
                var lineBreak = modalWindow.document.createElement('br');
                modalWindow.document.body.appendChild(lineBreak);
            } else {
                alert('Section non trouvée.');
                modalWindow.close();
            }
        }
    };
    xhr.send();
}



        
// Formatage d'un champs mail onKeypress="return valid_mail(event);"
function valid_mail(evt) {
    var keyCode = evt.which ? evt.which : evt.keyCode;
    var interdit = 'àâäãçéèêëìîïòôöõùûüñ &*?!:;,\t#~"^¨%$£?²¤§%*()[]{}<>|\\/`\'';
    if (interdit.indexOf(String.fromCharCode(keyCode)) >= 0) {
        return false;
    }
}

//Datalist recherche journal quand l'utilisateur tape des lettres
var liste_search_journal = function(my_libre) {
    var libre = my_libre;
    var data = "search_journal_datalist="+libre;
    send_xmlhttprequest2("entry_helper", data);
}

//Datalist recherche catégorie document quand l'utilisateur tape des lettres
var liste_search_cat_doc = function(my_libre) {
    var libre = my_libre;
    var data = "search_cat_doc_datalist="+libre;
    send_xmlhttprequest2("entry_helper", data);
}  

//Datalist recherche tag quand l'utilisateur tape des lettres
var liste_search_tag = function(my_libre) {
    var libre = my_libre;
    var data = "search_tag_datalist="+libre;
    send_xmlhttprequest2("entry_helper", data);
}  

//Datalist recherche libre id_paiement quand l'utilisateur tape des lettres
var liste_search_libre = function(my_libre) {
    var libre = my_libre;
    var data = "search_libre_datalist="+libre;
    send_xmlhttprequest2("entry_helper", data);
}

//Datalist recherche liste_search_compte quand l'utilisateur tape des lettres
var liste_search_compte = function(my_libre) {
    var libre = my_libre;
    var data = "search_compte_datalist="+libre;
    send_xmlhttprequest2("entry_helper", data);
}

//Datalist recherche liste_search_piece quand l'utilisateur tape des lettres
var liste_search_piece = function(my_libre, my_nb) {
    var libre = my_libre;
    var number = my_nb;
    var data = "search_piece_datalist="+libre+"&id_nb="+number;
    send_xmlhttprequest2("entry_helper", data);
} // var liste_search_piece = function(my_libre) 

//Datalist recherche liste_search_libelle quand l'utilisateur tape des lettres
var liste_search_libelle = function(my_libre, my_nb) {
    var libre = my_libre;
    var number = my_nb;
    var data = "search_libelle_datalist="+libre+"&id_nb="+number;
    send_xmlhttprequest2("entry_helper", data);
} // var liste_search_libelle = function(my_libre) 

//Datalist recherche liste_search_libfrais quand l'utilisateur tape des lettres
var liste_search_libfrais = function(my_libre, my_nb) {
    var libre = my_libre;
    var number = my_nb;
    var data = "search_libfrais_datalist="+libre+"&id_nb="+number;
    send_xmlhttprequest2("entry_helper", data);
} // var liste_search_libelle = function(my_libre) 

//Datalist recherche liste_search_lettrage quand l'utilisateur tape des lettres
var liste_search_lettrage = function(my_libre) {
    var libre = my_libre;
    var data = "search_lettrage_datalist="+libre;
    send_xmlhttprequest2("entry_helper", data);
} // var liste_search_lettrage = function(my_libre) 

//onclick appliquer list-expand
function myFunction(event) { 
  var x = event.target;
 // x.parentElement.classList.toggle('list-expand');
 x.classList.toggle('list-expand');
}

//onclick appliquer list-expand
function myFunctionchildren(event) { 
  var x = event.target;
 x.parentElement.classList.toggle('list-expand');
}

function searchFunction2() {
	var src, a, searchText, article, item, item_bar, input, filter, table, i, txtValue, myHilitor2;
	input = document.getElementById("Search");
	filter = input.value.toLowerCase().trim().split(' ');
	searchText = event.target.value;
	item = document.getElementsByClassName('main-section');
    item_bar = document.getElementsByClassName('nav-link');

	//surligner
	//myHilitor2 = new Hilitor2('main-section');
	//myHilitor2.setMatchType('left');
	//myHilitor2.apply(searchText);
	
	var myHilitor = new Hilitor2("playground");
	myHilitor.setMatchType("left");
	myHilitor.apply(searchText);
	
	
//filtrer	
	if ((searchText !== undefined) && (searchText !== null) && (searchText!== "")) {
		for (j = 0; j < filter.length; j++) {
		src = filter[j].trim();
			for (i = 0; i < item.length; i++) {
			if (src!='' && item ) {
				if ((item[i].innerText.toLowerCase().indexOf(filter[0]) !== -1 ) && (item[i].innerText.toLowerCase().indexOf(filter[j]) !== -1 )) {
				const sectionId = item[i].id;
				const sectionLink = document.querySelector(`a[href="#${sectionId}"]`);
				item[i].style.display = "";
				(sectionLink) && (sectionLink.style.display = "");
				} else {
				const sectionId = item[i].id;
				const sectionLink = document.querySelector(`a[href="#${sectionId}"]`);
				item[i].style.display = "none";
				(sectionLink) && (sectionLink.style.display = "none");	
				}
				}}
	}
	} else {location.reload();}
}

function Hilitor(id, tag) {

  // private variables
  var targetNode = document.getElementById(id) || document.body;
  var hiliteTag = tag || "MARK";
  var skipTags = new RegExp("^(?:" + hiliteTag + "|SCRIPT|FORM|SPAN)$");
  var colors = ["#ff6", "#a0ffff", "#9f9", "#f99", "#f6f"];
  var wordColor = [];
  var colorIdx = 0;
  var matchRegExp = "";
  var openLeft = false;
  var openRight = false;

  // characters to strip from start and end of the input string
  var endRegExp = new RegExp('^[^\\w]+|[^\\w]+$', "g");

  // characters used to break up the input string into words
  var breakRegExp = new RegExp('[^\\w\'-]+', "g");

  this.setEndRegExp = function(regex) {
    endRegExp = regex;
    return endRegExp;
  };

  this.setBreakRegExp = function(regex) {
    breakRegExp = regex;
    return breakRegExp;
  };

  this.setMatchType = function(type)
  {
    switch(type)
    {
      case "left":
        this.openLeft = false;
        this.openRight = true;
        break;

      case "right":
        this.openLeft = true;
        this.openRight = false;
        break;

      case "open":
        this.openLeft = this.openRight = true;
        break;

      default:
        this.openLeft = this.openRight = false;

    }
  };

  this.setRegex = function(input)
  {
    input = input.replace(endRegExp, "");
    input = input.replace(breakRegExp, "|");
    input = input.replace(/^\||\|$/g, "");
    if(input) {
      var re = "(" + input + ")";
      if(!this.openLeft) {
        re = "\\b" + re;
      }
      if(!this.openRight) {
        re = re + "\\b";
      }
      matchRegExp = new RegExp(re, "i");
      return matchRegExp;
    }
    return false;
  };

  this.getRegex = function()
  {
    var retval = matchRegExp.toString();
    retval = retval.replace(/(^\/(\\b)?|\(|\)|(\\b)?\/i$)/g, "");
    retval = retval.replace(/\|/g, " ");
    return retval;
  };

  // recursively apply word highlighting
  this.hiliteWords = function(node)
  {
    if(node === undefined || !node) return;
    if(!matchRegExp) return;
    if(skipTags.test(node.nodeName)) return;

    if(node.hasChildNodes()) {
      for(var i=0; i < node.childNodes.length; i++)
        this.hiliteWords(node.childNodes[i]);
    }
    if(node.nodeType == 3) { // NODE_TEXT

      var nv, regs;

      if((nv = node.nodeValue) && (regs = matchRegExp.exec(nv))) {

        if(!wordColor[regs[0].toLowerCase()]) {
          wordColor[regs[0].toLowerCase()] = colors[colorIdx++ % colors.length];
        }

        var match = document.createElement(hiliteTag);
        match.appendChild(document.createTextNode(regs[0]));
        match.style.backgroundColor = wordColor[regs[0].toLowerCase()];
        match.style.color = "#000";

        var after = node.splitText(regs.index);
        after.nodeValue = after.nodeValue.substring(regs[0].length);
        node.parentNode.insertBefore(match, after);

      }
    }
  };

  // remove highlighting
  this.remove = function()
  {
    var arr = document.getElementsByTagName(hiliteTag), el;
    while(arr.length && (el = arr[0])) {
      var parent = el.parentNode;
      parent.replaceChild(el.firstChild, el);
      parent.normalize();
    }
  };

  // start highlighting at target node
  this.apply = function(input)
  {
    this.remove();
    if(input === undefined || !(input = input.replace(/(^\s+|\s+$)/g, ""))) {
      return;
    }
    if(this.setRegex(input)) {
      this.hiliteWords(targetNode);
    }
    return matchRegExp;
  };

}

function Hilitor2(id, tag){

  // private variables
  var targetNode = document.getElementById(id) || document.body;
  var hiliteTag = tag || "MARK";
  var skipTags = new RegExp("^(?:" + hiliteTag + "|SCRIPT|FORM)$");
  var colors = ["#ff6", "#a0ffff", "#9f9", "#f99", "#f6f"];
  var wordColor = [];
  var colorIdx = 0;
  var matchRegExp = "";
  var openLeft = false;
  var openRight = false;
  var matches = [];

  // characters to strip from start and end of the input string
  var endRegExp = new RegExp('^[^\\w]+|[^\\w]+$', "g");

  // characters used to break up the input string into words
  var breakRegExp = new RegExp('[^\\w\'-]+', "g");

  this.setEndRegExp = function(regex)
  {
    endRegExp = regex;
    return true;
  };

  this.setBreakRegExp = function(regex)
  {
    breakRegExp = regex;
    return true;
  };

  this.setMatchType = function(type)
  {
    switch(type)
    {
      case "open":
        this.openLeft = this.openRight = true;
        break;

      case "closed":
        this.openLeft = this.openRight = false;
        break;

      case "right":
        this.openLeft = true;
        this.openRight = false;
        break;

      case "left":
      default:
        this.openLeft = false;
        this.openRight = true;

    }
    return true;
  };

  // break user input into words and convert to RegExp
  this.setRegex = function(input)
  {
    input = input.replace(/\\u[0-9A-F]{4}/g, ""); // remove missed unicode
    input = input.replace(endRegExp, "");
    input = input.replace(breakRegExp, "|");
    input = input.replace(/^\||\|$/g, "");
    input = addAccents(input);
    if(input) {
      var re = "(" + input + ")";
      if(!this.openLeft) {
        re = "(?:^|[\\b\\s])" + re;
      }
      if(!this.openRight) {
        re = re + "(?:[\\b\\s]|$)";
      }
      matchRegExp = new RegExp(re, "i");
      return matchRegExp;
    }
    return false;
  };

  this.getRegex = function()
  {
    var retval = matchRegExp.toString();
    retval = retval.replace(/(^\/|\(\?:[^\)]+\)|\/i$)/g, "");
    return retval;
  };

  // recursively apply word highlighting
  this.hiliteWords = function(node)
  {
    if(node === undefined || !node) return;
    if(!matchRegExp) return;
    if(skipTags.test(node.nodeName)) return;

    if(node.hasChildNodes()) {
      for(var i=0; i < node.childNodes.length; i++)
        this.hiliteWords(node.childNodes[i]);
    }
    if(node.nodeType == 3) { // NODE_TEXT
      if((nv = node.nodeValue) && (regs = matchRegExp.exec(nv))) {
        if(!wordColor[regs[1].toLowerCase()]) {
          wordColor[regs[1].toLowerCase()] = colors[colorIdx++ % colors.length];
        }

        var match = document.createElement(hiliteTag);
        match.appendChild(document.createTextNode(regs[1]));
        match.style.backgroundColor = wordColor[regs[1].toLowerCase()];
        match.style.color = "#000";

        var after;
        if(regs[0].match(/^\s/)) { // in case of leading whitespace
          after = node.splitText(regs.index + 1);
        } else {
          after = node.splitText(regs.index);
        }
        after.nodeValue = after.nodeValue.substring(regs[1].length);
        node.parentNode.insertBefore(match, after);
      }
    };
  };

  // remove highlighting
  this.remove = function()
  {
    var arr = document.getElementsByTagName(hiliteTag);
    while(arr.length && (el = arr[0])) {
      var parent = el.parentNode;
      parent.replaceChild(el.firstChild, el);
      parent.normalize();
    }
    return true;
  };

  // start highlighting at target node
  this.apply = function(input)
  {
    this.remove();
    if(input === undefined || !(input = input.replace(/(^\s+|\s+$)/g, ""))) {
      return;
    }
    input = escapeUnicode(input);
    input = removeUnicode(input);
    if(this.setRegex(input)) {
      this.hiliteWords(targetNode);
    }

    // build array of matches
    matches = targetNode.getElementsByTagName(hiliteTag);

    // return number of matches
    return matches.length;
  };

  // scroll to the nth match
  this.gotoMatch = function(idx)
  {
    if(matches[idx]) {
      matches[idx].scrollIntoView({
        behavior: "smooth",
        block: "center",
      });
      for(var i=0; i < matches.length; i++) {
        matches[i].style.outline = (idx == i) ? "2px solid red" : "";
      }
      return true;
    }
    return false;
  };

  // convert escaped UNICODE to ASCII
  function removeUnicode(input)
  {
    var retval = input;
    retval = retval.replace(/\\u(00E[024]|010[23]|00C2)/ig, "a");
    retval = retval.replace(/\\u00E7/ig, "c");
    retval = retval.replace(/\\u00E[89AB]/ig, "e");
    retval = retval.replace(/\\u(00E[EF]|00CE)/ig, "i");
    retval = retval.replace(/\\u00F[46]/ig, "o");
    retval = retval.replace(/\\u00F[9BC]/ig, "u");
    retval = retval.replace(/\\u00FF/ig, "y");
    retval = retval.replace(/\\u(00DF|021[89])/ig, "s");
    retval = retval.replace(/\\u(0163i|021[AB])/ig, "t");
    return retval;
  }

  // convert ASCII to wildcard
  function addAccents(input)
  {
    var retval = input;
    retval = retval.replace(/([ao])e/ig, "$1");
    retval = retval.replace(/ss/ig, "s");
    retval = retval.replace(/e/ig, "[eèéêë]");
    retval = retval.replace(/c/ig, "[cç]");
    retval = retval.replace(/i/ig, "[iîï]");
    retval = retval.replace(/u/ig, "[uùûü]");
    retval = retval.replace(/y/ig, "[yÿ]");
    retval = retval.replace(/s/ig, "(ss|[sßș])");
    retval = retval.replace(/t/ig, "([tţț])");
    retval = retval.replace(/a/ig, "([aàâäă]|ae)");
    retval = retval.replace(/o/ig, "([oôö]|oe)");
    return retval;
  }

  // added by Yanosh Kunsh to include utf-8 string comparison
  function dec2hex4(textString)
  {
    var hexequiv = new Array("0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F");
    return hexequiv[(textString >> 12) & 0xF] + hexequiv[(textString >> 8) & 0xF] + hexequiv[(textString >> 4) & 0xF] + hexequiv[textString & 0xF];
  }

  // escape UNICODE characters in string
  function escapeUnicode(str)
  {
    // convertCharStr2jEsc
    // Converts a string of characters to JavaScript escapes
    // str: sequence of Unicode characters
    var highsurrogate = 0;
    var suppCP;
    var pad;
    var n = 0;
    var outputString = "";
    for(var i=0; i < str.length; i++) {
      var cc = str.charCodeAt(i);
      if(cc < 0 || cc > 0xFFFF) {
        outputString += '!Error in convertCharStr2UTF16: unexpected charCodeAt result, cc=' + cc + '!';
      }
      if(highsurrogate != 0) { // this is a supp char, and cc contains the low surrogate
        if(0xDC00 <= cc && cc <= 0xDFFF) {
          suppCP = 0x10000 + ((highsurrogate - 0xD800) << 10) + (cc - 0xDC00);
          suppCP -= 0x10000;
          outputString += '\\u' + dec2hex4(0xD800 | (suppCP >> 10)) + '\\u' + dec2hex4(0xDC00 | (suppCP & 0x3FF));
          highsurrogate = 0;
          continue;
        } else {
          outputString += 'Error in convertCharStr2UTF16: low surrogate expected, cc=' + cc + '!';
          highsurrogate = 0;
        }
      }
      if(0xD800 <= cc && cc <= 0xDBFF) { // start of supplementary character
        highsurrogate = cc;
      } else { // this is a BMP character
        switch(cc)
        {
          case 0:
            outputString += '\\0';
            break;
          case 8:
            outputString += '\\b';
            break;
          case 9:
            outputString += '\\t';
            break;
          case 10:
            outputString += '\\n';
            break;
          case 13:
            outputString += '\\r';
            break;
          case 11:
            outputString += '\\v';
            break;
          case 12:
            outputString += '\\f';
            break;
          case 34:
            outputString += '\\\"';
            break;
          case 92:
            outputString += '\\\\';
            break;
          default:
            if(cc > 0x1f && cc < 0x7F) {
              outputString += String.fromCharCode(cc);
            } else {
              pad = cc.toString(16).toUpperCase();
              while(pad.length < 4) {
                pad = '0' + pad;
              }
              outputString += '\\u' + pad;
            }
        }
      }
    }
    return outputString;
  }

}
