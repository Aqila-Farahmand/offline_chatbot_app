# llmService and related classes for robust LLM API interaction
import requests
import json


class LanguageModelProvider:
    def use(self, language_model: str, system_prompt: str):
        raise NotImplementedError


class LanguageModel:
    def ask(self, question: str, max_output=4096) -> str:
        raise NotImplementedError


class llmService(LanguageModelProvider):
    def __init__(self, host: str, port: int):
        self.host = host
        self.port = port

    def use(self, language_model: str, system_prompt: str) -> LanguageModel:
        return llmModel(self.host, self.port, language_model, system_prompt)

    def __str__(self):
        return f'llmService(host={self.host}, port={self.port})'

    def __repr__(self):
        return self.__str__()


class llmModel(LanguageModel):
    def __init__(self, host: str, port: int, name: str, system: str):
        self.host = host
        self.port = port
        self.system = system
        self.name = name

    def ask(self, question: str, max_output=4096) -> str:
        payload = {
            'model': self.name,
            'prompt': f'{question}',
            'stream': False,
            'system': self.system,
            'options': {
                'num_predict': max_output
            }
        }
        url = f'http://{self.host}:{self.port}/api/generate'
        reply = requests.post(url, data=json.dumps(payload))
        reply.raise_for_status()
        return llmModel._pretty_format(reply.json()['response'])

    @staticmethod
    def _pretty_format(response: str) -> str:
        response = response.replace('"', '')
        response = f'"{response}"'
        return response

    def __str__(self):
        return f'llmModel(host={self.host}, port={self.port}, name={self.name}, system={self.system})'

    def __repr__(self):
        return self.__str__()
