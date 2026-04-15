using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

public sealed class GameManager : MonoBehaviour
{
    public TankHealth player;
    public Text statusText;
    public Text objectiveText;

    readonly List<TankHealth> enemies = new List<TankHealth>();
    bool gameOver;

    void Start()
    {
        if (player != null)
        {
            player.OnDeath += HandlePlayerDeath;
        }

        UpdateObjective();
        SetStatus("Destroy all enemy tanks");
    }

    void Update()
    {
        if (gameOver && (Input.GetKeyDown(KeyCode.Return) || Input.GetKeyDown(KeyCode.Space)))
        {
            SceneManager.LoadScene(SceneManager.GetActiveScene().buildIndex);
        }
    }

    public void RegisterEnemy(TankHealth enemy)
    {
        if (enemy == null || enemies.Contains(enemy))
        {
            return;
        }

        enemies.Add(enemy);
        enemy.OnDeath += HandleEnemyDeath;
        UpdateObjective();
    }

    void HandlePlayerDeath(TankHealth health)
    {
        gameOver = true;
        SetStatus("Defeat - press Enter or Space to restart");
    }

    void HandleEnemyDeath(TankHealth health)
    {
        enemies.Remove(health);
        health.OnDeath -= HandleEnemyDeath;
        health.gameObject.SetActive(false);
        UpdateObjective();

        if (enemies.Count == 0 && !gameOver)
        {
            gameOver = true;
            SetStatus("Victory - press Enter or Space to restart");
        }
    }

    void UpdateObjective()
    {
        if (objectiveText != null)
        {
            objectiveText.text = "Enemies: " + enemies.Count;
        }
    }

    void SetStatus(string message)
    {
        if (statusText != null)
        {
            statusText.text = message;
        }
    }
}
