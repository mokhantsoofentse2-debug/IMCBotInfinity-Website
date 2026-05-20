<script>
    const params = new URLSearchParams(window.location.search);
    const botType = params.get('bot');

    // Central Database for your bots
    const botDatabase = {
        'sa': {
            title: "Small Account Setup",
            pass: "IMCBOTSA_9922",
            file: "files/IMCBOT_SA.mq5"
        },
        'master': {
            title: "Master Bot Setup",
            pass: "IMCBOTMaster_101033", 
            file: "files/IMCBOT_Master.mq5"
        },
        'king': {
            title: "King Bot Setup",
            pass: "IMCBOTKing_10111",
            file: "files/IMCBOT_KING.mq5"
        },
        'asura': {
            title: "Asura Bot Setup",
            pass: "IMCBOTAsura_10112",
            file: "files/IMCBOT_ASURA.mq5"
        }
    };

    // Initialize Page
    const currentBot = botDatabase[botType];
    if (currentBot) {
        document.getElementById('botTitle').innerText = "IMCBOT " + currentBot.title;
    } else {
        document.getElementById('botTitle').innerText = "Invalid Bot Selected";
    }

// Replaced new
function verifyBot() {
    const accNum = document.getElementById('accNum').value;
    const inputPass = document.getElementById('pass').value;

    if (currentBot && inputPass === currentBot.pass) {
        // 1. Send signal to your database (Example using a fetch call)
        fetch('https://your-api.com/register-bot', {
            method: 'POST',
            body: JSON.stringify({ account: accNum, bot: botType, status: 'active' })
        });

        // 2. Show the success UI
        document.getElementById('verifyBtn').innerText = "System Synced!";
        document.getElementById('downloadArea').style.display = 'block';
        startSlideshow();
    }
}
</script>
